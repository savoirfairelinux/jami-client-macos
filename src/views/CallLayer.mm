/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *  Author: Anthony Léonard <anthony.leonard@savoirfairelinux.com>
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

#import "CallLayer.h"
#import <OpenGL/gl3.h>

static const GLchar* vShaderSrc = R"glsl(
#version 150

in vec2 in_Pos;
in vec2 in_TexCoord;
uniform vec2 in_Scaling;

out vec2 texCoord;

void main()
{
    texCoord = in_TexCoord;
    gl_Position = vec4(in_Pos.x*in_Scaling.x, in_Pos.y*in_Scaling.y, 0.0, 1.0);
}
)glsl";

static const GLchar* fShaderSrc = R"glsl(
#version 150

in vec2 texCoord;

uniform sampler2D textureY, textureUV;

void main()
{
mediump vec3 yuv;
lowp vec3 rgb;

yuv.x = (texture2D(textureY, texCoord).r - (16.0/255.0));
yuv.yz = (texture2D(textureUV, texCoord).ra - vec2(0.5, 0.5));

rgb =   yuv*colorConversionMatrix;

gl_FragColor = vec4(rgb,1);
}
)glsl";


@implementation CallLayer

// OpenGL handlers
GLuint textureY, textureUV, textureUniformY, textureUniformUV, vbo, vShader, fShader, sProg, vao;

// Last frame data and attributes
CVPixelBufferRef currentFrame;
CGFloat currentWidth;
CGFloat currentHeight;
BOOL currentFrameDisplayed;
NSLock* currentFrameLk;

- (id) init
{
    self = [super init];
    if (self) {
        currentFrameLk = [[NSLock alloc] init];
        [self setVideoRunning:NO];
    }
    return self;
}

// This setter is redefined so we can initialize the OpenGL context when this one is
// setup by the UI (which seems to be done just before the first draw attempt and not in init method);
- (void)setOpenGLContext:(NSOpenGLContext *)openGLContext
{
    [super setOpenGLContext:openGLContext];

    if (openGLContext) {
        GLfloat vertices[] = {
            -1.0, 1.0, 0.0, 0.0,   // Top-left
            1.0, 1.0, 1.0, 0.0,    // Top-right
            -1.0, -1.0, 0.0, 1.0,  // Bottom-left
            1.0, -1.0, 1.0, 1.0    // Bottom-right
        };

        [openGLContext makeCurrentContext];

        // VAO
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);

        // VBO
        glGenBuffers(1, &vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

        // Vertex shader
        vShader = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vShader, 1, &vShaderSrc, NULL);
        glCompileShader(vShader);

        // Fragment shader
        fShader = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(fShader, 1, &fShaderSrc, NULL);
        glCompileShader(fShader);

        // Program
        sProg = glCreateProgram();
        glAttachShader(sProg, vShader);
        glAttachShader(sProg, fShader);
        glBindFragDataLocation(sProg, 0, "fragColor");
        glLinkProgram(sProg);
        glUseProgram(sProg);
        
       // textureUniformY = glGetUniformLocation(sProg, "tex_y");
       // textureUniformUV = glGetUniformLocation(sProg, "tex_u");


        // Vertices position attrib
        GLuint inPosAttrib = glGetAttribLocation(sProg, "in_Pos");
        glEnableVertexAttribArray(inPosAttrib);
        glVertexAttribPointer(inPosAttrib, 2, GL_FLOAT, GL_FALSE, 4*sizeof(GLfloat), 0);

        // Texture position attrib
        GLuint inTexCoordAttrib = glGetAttribLocation(sProg, "in_TexCoord");
        glEnableVertexAttribArray(inTexCoordAttrib);
        glVertexAttribPointer(inTexCoordAttrib, 2, GL_FLOAT, GL_FALSE, 4*sizeof(GLfloat), (void*)(2*sizeof(GLfloat)));

        // TextureY
      //  glActiveTexture(GL_TEXTURE0);
        glGenTextures(1, &textureY);
        glBindTexture(GL_TEXTURE_2D, textureY);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
        
        // TextureUV
      //  glActiveTexture(GL_TEXTURE1);
         glGenTextures(1, &textureUV);
         glBindTexture(GL_TEXTURE_2D, textureUV);
         glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
         glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
         glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
         glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);

    }
}

- (NSOpenGLPixelFormat *)openGLPixelFormatForDisplayMask:(uint32_t)mask
{
    NSOpenGLPixelFormatAttribute attrs[] = {
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAScreenMask,
        mask,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFAOpenGLProfile,
        NSOpenGLProfileVersion3_2Core,
        0
    };

    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];

    return pixelFormat;
}

- (BOOL)isAsynchronous
{
    return YES;
}
unsigned char* m_pBufYuv420p;

- (void)drawInOpenGLContext:(NSOpenGLContext *)context pixelFormat:(NSOpenGLPixelFormat *)pixelFormat forLayerTime:(CFTimeInterval)t displayTime:(const CVTimeStamp *)ts
{
    GLenum errEnum;
   // glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
   // glClear(GL_COLOR_BUFFER_BIT);

    [currentFrameLk lock];
    CVPixelBufferLockBaseAddress(currentFrame, 0);
    // To ensure that we will not divide by zero
//    if (currentFrame&& currentWidth && currentHeight) {
//        // Compute scaling factor to keep the original aspect ratio of the video
//        CGSize viewSize = self.frame.size;
//        float viewRatio = viewSize.width/viewSize.height;
//        float frameRatio = ((float)currentWidth)/((float)currentHeight);
//        float ratio = viewRatio * (1/frameRatio);
//
//        GLint inScalingUniform = glGetUniformLocation(sProg, "in_Scaling");
//
//        float multiplier = MAX(frameRatio, ratio);
//        if((viewRatio >= 1 && frameRatio >= 1) ||
//           (viewRatio < 1 && frameRatio < 1) ||
//           (ratio > 0.5 && ratio < 1.5) ) {
//            if (ratio > 1.0)
//                glUniform2f(inScalingUniform, 1.0, 1.0 * ratio);
//            else
//                glUniform2f(inScalingUniform, 1.0/ratio, 1.0);
//        } else {
//            if (ratio < 1.0)
//                glUniform2f(inScalingUniform, 1.0, 1.0 * ratio);
//            else
//                glUniform2f(inScalingUniform, 1.0/ratio, 1.0);
//
//        }
//    }
    
    if(!currentFrameDisplayed) {
           if(currentFrame) {
              // CVPixelBufferLockBaseAddress(currentFrame, 0);

               // Get the number of bytes per row for the pixel buffer
               void *baseAddress = CVPixelBufferGetBaseAddressOfPlane(currentFrame, 0);
               void *baseAddress1 = CVPixelBufferGetBaseAddressOfPlane(currentFrame, 1);
               void *baseAddress11 = CVPixelBufferGetBaseAddress(currentFrame);
              // glActiveTexture(GL_TEXTURE0);
               glBindTexture(GL_TEXTURE_2D, textureY);
               glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, currentWidth, currentHeight, 0, GL_RED, GL_UNSIGNED_BYTE, baseAddress11);
              // glUniform1i(textureUniformY, 0);
              // glActiveTexture(GL_TEXTURE1);
               glBindTexture(GL_TEXTURE_2D, textureUV);
               glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, currentWidth, currentHeight * 0.5, 0, GL_RED, GL_UNSIGNED_BYTE, baseAddress11);
              // glUniform1i(textureUniformUV, 1);
           }
           currentFrameDisplayed = YES;
       }
    [currentFrameLk unlock];

   // if([self videoRunning])
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    CVPixelBufferUnlockBaseAddress(currentFrame, 0);
}

- (void) setCurrentFrame:(CVPixelBufferRef)framePtr width:(CGFloat)width height:(CGFloat)height {

//- (void) setCurrentFrame:(Video::Frame)framePtr
//{
    [currentFrameLk lock];
    currentFrame = framePtr;//std::move(framePtr);
    currentWidth = width;
    currentHeight = height;
    currentFrameDisplayed = NO;
    [currentFrameLk unlock];
}

@end
