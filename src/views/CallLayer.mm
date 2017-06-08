/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

out vec4 fragColor;
in vec2 texCoord;

uniform sampler2D tex;

void main()
{
    fragColor = texture(tex, texCoord);
}
)glsl";

@implementation CallLayer

// OpenGL handlers
GLuint tex_, vbo_, vShader_, fShader_, sProg_, vao_;

// Last frame data and attributes
Video::Frame currentFrame_;
QSize currentFrameSize_;
BOOL currentFrameDisplayed_;
NSLock* currentFrameLk_;

- (id) init
{
    self = [super init];
    if (self) {
        currentFrameLk_ = [[NSLock alloc] init];
        [self setVideoRunning:NO];
    }
    return self;
}

// This setter is redefined so we can initialize the OpenGL context when this one is
// setup by the UI (which seems to be done just before the first draw attempt and not in init method);
- (void)setOpenGLContext:(NSOpenGLContext *)openGLContext
{
    [super setOpenGLContext:openGLContext];

    if (openGLContext)
    {
        GLfloat vertices[] = {
            -1.0, 1.0, 0.0, 0.0,   // Top-left
            1.0, 1.0, 1.0, 0.0,    // Top-right
            -1.0, -1.0, 0.0, 1.0,  // Bottom-left
            1.0, -1.0, 1.0, 1.0    // Bottom-right
        };

        [openGLContext makeCurrentContext];

        // VAO
        glGenVertexArrays(1, &vao_);
        glBindVertexArray(vao_);

        // VBO
        glGenBuffers(1, &vbo_);
        glBindBuffer(GL_ARRAY_BUFFER, vbo_);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

        // Vertex shader
        vShader_ = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vShader_, 1, &vShaderSrc, NULL);
        glCompileShader(vShader_);

        // Fragment shader
        fShader_ = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(fShader_, 1, &fShaderSrc, NULL);
        glCompileShader(fShader_);

        // Program
        sProg_ = glCreateProgram();
        glAttachShader(sProg_, vShader_);
        glAttachShader(sProg_, fShader_);
        glBindFragDataLocation(sProg_, 0, "fragColor");
        glLinkProgram(sProg_);
        glUseProgram(sProg_);

        // Vertices position attrib
        GLuint inPosAttrib = glGetAttribLocation(sProg_, "in_Pos");
        glEnableVertexAttribArray(inPosAttrib);
        glVertexAttribPointer(inPosAttrib, 2, GL_FLOAT, GL_FALSE, 4*sizeof(GLfloat), 0);

        // Texture position attrib
        GLuint inTexCoordAttrib = glGetAttribLocation(sProg_, "in_TexCoord");
        glEnableVertexAttribArray(inTexCoordAttrib);
        glVertexAttribPointer(inTexCoordAttrib, 2, GL_FLOAT, GL_FALSE, 4*sizeof(GLfloat), (void*)(2*sizeof(GLfloat)));

        // Texture
        glGenTextures(1, &tex_);
        glBindTexture(GL_TEXTURE_2D, tex_);
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
    glBindTexture(GL_TEXTURE_2D, tex_);

    [currentFrameLk_ lock];
    if(!currentFrameDisplayed_)
    {
        if(currentFrame_.ptr)
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, currentFrameSize_.width(), currentFrameSize_.height(), 0, GL_RGBA, GL_UNSIGNED_BYTE, currentFrame_.ptr);
        currentFrameDisplayed_ = YES;
    }

    if (!currentFrameSize_.isEmpty()) // To ensure that we will not divide by zero
    {
        // Compute scaling factor to keep the original aspect ratio of the video
        CGSize viewSize = self.frame.size;
        float viewRatio = viewSize.width/viewSize.height;
        float frameRatio = ((float)currentFrameSize_.width())/((float)currentFrameSize_.height());
        float ratio = viewRatio * (1/frameRatio);

        GLint inScalingUniform = glGetUniformLocation(sProg_, "in_Scaling");

        if (ratio < 1.0)
            glUniform2f(inScalingUniform, 1.0, ratio);
        else
            glUniform2f(inScalingUniform, 1.0/ratio, 1.0);
    }
    [currentFrameLk_ unlock];

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    if([self videoRunning])
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void) setCurrentFrame:(Video::Frame)framePtr ofSize:(QSize)frameSize
{
    [currentFrameLk_ lock];
    currentFrame_ = std::move(framePtr);
    currentFrameSize_ = frameSize;
    currentFrameDisplayed_ = NO;
    [currentFrameLk_ unlock];
}

@end
