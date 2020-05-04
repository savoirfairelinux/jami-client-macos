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
#import <VideoToolbox/VideoToolbox.h>

extern "C" {
#import "libavutil/frame.h"
#import "libavutil/display.h"
}

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

out vec4 fragColor;
in vec2 texCoord;

uniform sampler2D tex_y, tex_uv;

void main()
{
     gl_FragColor = vec4(1,0,0,1);
}
)glsl";

@interface CallLayer()

@property BOOL currentFrameDisplayed;
@property NSLock* currentFrameLk;

@property CGFloat currentWidth;

@property CGFloat currentHeight;

@end

@implementation CallLayer

// OpenGL handlers
GLuint textureY, textureUV, textureUniformY, textureUniformUV, vbo, vShader, fShader, sProg, vao;

@synthesize currentFrameDisplayed, currentFrameLk, currentWidth, currentHeight;

AVFrame currentFrame;

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
        textureUniformY = glGetUniformLocation(sProg, "tex_y");
        textureUniformUV = glGetUniformLocation(sProg, "tex_uv");
        
         //Vertices position attrib
        GLuint inPosAttrib = glGetAttribLocation(sProg, "in_Pos");
        glEnableVertexAttribArray(inPosAttrib);
        glVertexAttribPointer(inPosAttrib, 2, GL_FLOAT, GL_FALSE, 4*sizeof(GLfloat), 0);

        // Texture position attrib
        GLuint inTexCoordAttrib = glGetAttribLocation(sProg, "in_TexCoord");
        glEnableVertexAttribArray(inTexCoordAttrib);
        glVertexAttribPointer(inTexCoordAttrib, 2, GL_FLOAT, GL_FALSE, 4*sizeof(GLfloat), (void*)(2*sizeof(GLfloat)));
        // TextureY
        glActiveTexture(GL_TEXTURE0);
        glGenTextures(1, &textureY);
        glBindTexture(GL_TEXTURE_2D, textureY);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
        // TextureUV
        glActiveTexture(GL_TEXTURE1);
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

- (void)drawInOpenGLContext:(NSOpenGLContext *)context pixelFormat:(NSOpenGLPixelFormat *)pixelFormat forLayerTime:(CFTimeInterval)t displayTime:(const CVTimeStamp *)ts
{
    GLenum errEnum;
    
    [currentFrameLk lock];
    if(!currentFrameDisplayed) {

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, textureY);
        const uint8_t* uploadPlane = currentFrame.data[0];
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, currentFrame.width, currentFrame.height, 0, GL_RED, GL_UNSIGNED_BYTE, uploadPlane);
        glUniform1i(textureUniformY, 0);

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, textureUV);
        const uint8_t* uploadPlane1 = currentFrame.data[1];

        glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, currentWidth, currentHeight, 0, GL_RED, GL_UNSIGNED_BYTE, uploadPlane1);

        glUniform1i(textureUniformUV, 1);
        currentFrameDisplayed = YES;
    }
    [currentFrameLk unlock];
    
    if (currentFrame.data[0] && currentFrame.width && currentFrame.height) {
        // Compute scaling factor to keep the original aspect ratio of the video
        CGSize viewSize = self.frame.size;
        float viewRatio = viewSize.width/viewSize.height;
        float frameRatio = ((float)currentFrame.width)/((float)currentFrame.height);
        float ratio = viewRatio * (1/frameRatio);
        GLint inScalingUniform = glGetUniformLocation(sProg, "in_Scaling");
        float multiplier = MAX(frameRatio, ratio);
        if((viewRatio >= 1 && frameRatio >= 1) ||
           (viewRatio < 1 && frameRatio < 1) ||
           (ratio > 0.5 && ratio < 1.5) ) {
            if (ratio > 1.0)
                glUniform2f(inScalingUniform, 1.0, 1.0 * ratio);
            else
                glUniform2f(inScalingUniform, 1.0/ratio, 1.0);
        } else {
            if (ratio < 1.0)
                glUniform2f(inScalingUniform, 1.0, 1.0 * ratio);
            else
                glUniform2f(inScalingUniform, 1.0/ratio, 1.0);
        }
    }
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    if([self videoRunning])
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void) setCurrentFrame:(lrc::api::video::Frame)framePtr
{
}

-(void)renderAVFrame:(std::unique_ptr<AVFrame, void(*)(AVFrame*)>)buffer
{
    [currentFrameLk lock];
        auto ptr = buffer.get();
    if(ptr) {
    currentFrame = *buffer.get();
        }
    currentFrameDisplayed = NO;
    [currentFrameLk unlock];
}

@end
