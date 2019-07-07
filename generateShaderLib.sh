xcrun -sdk macosx metal -c ../src/Shader.metal -o ../Shader.air
xcrun -sdk macosx metallib ../Shader.air -o ../Shader.metallib
