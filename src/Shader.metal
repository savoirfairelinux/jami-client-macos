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
#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

typedef enum VertexAttributes {
    kVertexAttributePosition  = 0,
    kVertexAttributeTexcoord  = 1,
    } VertexAttributes;

    typedef enum TextureIndices {
        kTextureIndexColor  = 0,
        kTextureIndexY      = 1,
        kTextureIndexCbCr   = 2
        } TextureIndices;

        typedef struct {
            float2 position [[attribute(kVertexAttributePosition)]];
            float2 texCoord [[attribute(kVertexAttributeTexcoord)]];
        } ImageVertex;

        typedef struct {
            float4 position [[position]];
            float2 texCoord;
        } ImageColorInOut;

        struct Uniforms {
            float4x4 projectionMatrix;
            float4x4 rotationMatrix;
        };

        vertex ImageColorInOut imageVertex(ImageVertex in [[stage_in]],
                                           constant Uniforms &uniforms [[buffer(1)]]) {
            ImageColorInOut out;
            out.position = uniforms.rotationMatrix * uniforms.projectionMatrix * float4(in.position, 1.0);
            out.texCoord = in.texCoord;
            return out;
        }

        fragment float4 imageFragment(ImageColorInOut in [[stage_in]],
                                      texture2d<float, access::sample> capturedImageTextureY [[ texture(kTextureIndexY) ]],
                                      texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(kTextureIndexCbCr) ]]) {
            constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
            const float4x4 ycbcrToRGBTransform = float4x4(float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                                          float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                                          float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                                          float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f));

            // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
            float4 ycbcr = float4(capturedImageTextureY.sample(colorSampler, in.texCoord).r,
                                  capturedImageTextureCbCr.sample(colorSampler, in.texCoord).rg, 1.0);

            return ycbcrToRGBTransform * ycbcr;
        }




