/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

#import "CallMTKView.h"

@implementation CallMTKView {
     id <MTLBuffer> vertexBuffer;
     id <MTLDepthStencilState> depthState;
     id<MTLCommandQueue> commandQueue;
     id<MTLRenderPipelineState> pipeline;
     CVMetalTextureCacheRef textureCache;
}

// Vertex data for an image plane
static const float kImagePlaneVertexData[16] = {
    -1.0, -1.0,  0.0, 1.0,
    1.0, -1.0,  1.0, 1.0,
    -1.0,  1.0,  0.0, 0.0,
    1.0,  1.0,  1.0, 0.0,
};

typedef enum BufferIndices {
    kBufferIndexMeshPositions    = 0,
} BufferIndices;

typedef enum VertexAttributes {
    kVertexAttributePosition  = 0,
    kVertexAttributeTexcoord  = 1,
} VertexAttributes;

struct Uniforms {
    simd::float4x4 projectionMatrix;
    simd::float4x4 rotationMatrix;
};

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

-(void)setupView {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    self.device = device;
    commandQueue = [device newCommandQueue];
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    commandQueue = [device newCommandQueue];

    CVReturn err = CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                             NULL,
                                             self.device,
                                             NULL,
                                             &textureCache);

    vertexBuffer = [device newBufferWithBytes:&kImagePlaneVertexData
                                       length:sizeof(kImagePlaneVertexData)
                                      options:MTLResourceCPUCacheModeDefaultCache];

    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *libraryPath = [resourcePath stringByAppendingPathComponent:@"Shader.metallib"];
    id <MTLLibrary> library = [device newLibraryWithFile:libraryPath error:nil];
    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"imageVertex"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"imageFragment"];

    // Create a vertex descriptor for our image plane vertex buffer
    MTLVertexDescriptor *imagePlaneVertexDescriptor = [[MTLVertexDescriptor alloc] init];

    // Positions.
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].format = MTLVertexFormatFloat2;
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].offset = 0;
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].bufferIndex = kBufferIndexMeshPositions;

    // Texture coordinates.
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].format = MTLVertexFormatFloat2;
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].offset = 8;
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].bufferIndex = kBufferIndexMeshPositions;

    // Position Buffer Layout
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stride = 16;
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stepRate = 1;
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;

    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.vertexFunction = vertexFunc;
    pipelineDescriptor.fragmentFunction = fragmentFunc;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.vertexDescriptor = imagePlaneVertexDescriptor;

    pipeline = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:NULL];
    MTLDepthStencilDescriptor *depthStateDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDescriptor.depthCompareFunction = MTLCompareFunctionAlways;
    depthStateDescriptor.depthWriteEnabled = NO;
    depthState = [device newDepthStencilStateWithDescriptor:depthStateDescriptor];
    self.preferredFramesPerSecond = 30;
}

- (void)fillWithBlack {
    NSUInteger width = self.frame.size.width;
    NSUInteger height = self.frame.size.height;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    uint8_t *rawData = (uint8_t *)calloc(height * width * 4, sizeof(uint8_t));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    MTLTextureDescriptor *textureDescriptor =
    [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                       width:width
                                                      height:height
                                                   mipmapped:YES];
    textureDescriptor.usage = MTLTextureUsageRenderTarget;
    id<MTLTexture> texture = [self.device newTextureWithDescriptor:textureDescriptor];
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [texture replaceRegion:region mipmapLevel:0 withBytes:rawData bytesPerRow:bytesPerRow];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPass = self.currentRenderPassDescriptor;
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
    [commandEncoder setFragmentTexture:texture atIndex:0];
    [commandEncoder endEncoding];
    [commandBuffer presentDrawable:self.currentDrawable];
    [commandBuffer commit];
}

bool frameDisplayed = false;

- (void)renderWithPixelBuffer:(CVPixelBufferRef)buffer
                         size:(CGSize)size
                     rotation: (float)rotation
                    fillFrame: (bool)fill {
    if(frameDisplayed) {
        return;
    }
    if(_stopRendering) {
        self.releaseDrawables;
        return;
    }
    if (buffer == nil) return;
    frameDisplayed = true;
    CFRetain(buffer);
    CVPixelBufferLockBaseAddress(buffer, 0);
    id<MTLTexture> textureY = [self getTexture:buffer pixelFormat:MTLPixelFormatR8Unorm planeIndex:0];
    id<MTLTexture> textureCbCr = [self getTexture:buffer pixelFormat:MTLPixelFormatRG8Unorm planeIndex:1];
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    if(textureY == NULL || textureCbCr == NULL) {
        frameDisplayed = false;
        CVPixelBufferRelease(buffer);
        return;
    }
    id<CAMetalDrawable> drawable = self.currentDrawable;
    if (!drawable.texture) {
        frameDisplayed = false;
        CVPixelBufferRelease(buffer);
        return;
    }
    NSSize frameSize = self.frame.size;

    float viewRatio = (rotation == 90 || rotation == -90) ?
    frameSize.height/frameSize.width : frameSize.width/frameSize.height;
    float frameRatio = ((float)size.width)/((float)size.height);
    simd::float4x4 projectionMatrix;
    float ratio = viewRatio * (1/frameRatio);
    if((viewRatio >= 1 && frameRatio >= 1) ||
       (viewRatio < 1 && frameRatio < 1) ||
       (ratio > 0.5 && ratio < 1.5) ) {
        if (ratio <= 1.0 && ratio >= 0.5)
            projectionMatrix = [self getScalingMatrix: 1/ratio axis: 'x'];
        else if (ratio < 0.5)
            projectionMatrix = [self getScalingMatrix: ratio axis: 'y'];
        else if (ratio > 1 && ratio < 2)
            projectionMatrix = [self getScalingMatrix: ratio axis: 'y'];
        else
            projectionMatrix = [self getScalingMatrix: 1/ratio axis: 'x'];
    } else {
        if (ratio < 1.0 && !fill || fill && ratio > 1.0)
            projectionMatrix = [self getScalingMatrix: ratio axis: 'y'];
        else
            projectionMatrix = [self getScalingMatrix: 1/ratio axis: 'x'];
    }
    float radians = (-rotation * M_PI) / 180;
    simd::float4x4 rotationMatrix = [self getRotationMatrix:radians];
    Uniforms bytes = Uniforms{projectionMatrix: projectionMatrix, rotationMatrix: rotationMatrix};
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> cbuffer) {
        frameDisplayed = false;
        CVPixelBufferRelease(buffer);
    }];
    MTLRenderPassDescriptor *renderPass = self.currentRenderPassDescriptor;
    renderPass.colorAttachments[0].texture = drawable.texture;
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
    [commandEncoder setRenderPipelineState: pipeline];
    [commandEncoder setDepthStencilState:depthState];
    [commandEncoder setVertexBytes: &bytes length:sizeof(bytes) atIndex:1];
    [commandEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:kBufferIndexMeshPositions];
    [commandEncoder setFragmentTexture:textureY atIndex: 1];
    [commandEncoder setFragmentTexture:textureCbCr atIndex:2];
    [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [commandEncoder endEncoding];
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

-(simd::float4x4) getScalingMatrix:(CGFloat) ratio axis:(char) axis {
    simd::float4x4 N = 0.0;
    simd::float4 v[4] = {0.0, 0.0, 0.0, 0.0};
    float xMultyplier = axis == 'x' ? ratio: 1;
    float yMultyplier = axis == 'y' ? ratio: 1;
    v[0] = { xMultyplier,  0,  0,  0 };
    v[1] = {  0,  yMultyplier,  0,  0 };
    v[2] = {  0,  0, 1, 0 };
    v[3] = { 0, 0, 0, 1 };
    N =  matrix_from_rows(v[0], v[1], v[2], v[3]);
    return N;
}

-(simd::float4x4) getRotationMatrix:(float) rotation {
    simd::float4x4 N = 0.0;
    simd::float4 v[4] = {0.0, 0.0, 0.0, 0.0};
    v[0] = {  cos(rotation),  sin(rotation),  0,  0 };
    v[1] = {  -sin(rotation),  cos(rotation),  0,  0 };
    v[2] = {  0,  0, 1, 0 };
    v[3] = { 0, 0, 0, 1 };
    N =  matrix_from_rows(v[0], v[1], v[2], v[3]);
    return N;
}

- (id<MTLTexture>)getTexture:(CVPixelBufferRef)image pixelFormat:(MTLPixelFormat)pixelFormat planeIndex:(int)planeIndex {
    id<MTLTexture> texture;
    size_t width, height;
    if (planeIndex == -1)
    {
        width = CVPixelBufferGetWidth(image);
        height = CVPixelBufferGetHeight(image);
        planeIndex = 0;
    }
    else
    {
        width = CVPixelBufferGetWidthOfPlane(image, planeIndex);
        height = CVPixelBufferGetHeightOfPlane(image, planeIndex);
    }
    auto format = CVPixelBufferGetPixelFormatType(image);
    CVMetalTextureRef textureRef = NULL;
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, textureCache, image, NULL, pixelFormat, width, height, planeIndex, &textureRef);
    if(status == kCVReturnSuccess)
    {
        texture = CVMetalTextureGetTexture(textureRef);
        CFRelease(textureRef);
    }
    else
    {
        NSLog(@"CVMetalTextureCacheCreateTextureFromImage failed with return stats %d", status);
        return NULL;
    }
    return texture;
}

@end
