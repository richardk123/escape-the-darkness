struct VertexOut {
    @builtin(position) position_clip: vec4<f32>,
    @location(0) color: vec3<f32>,
}

struct Instance {
    position: vec3<f32>,
    rotation: vec4<f32>,
    scale: vec3<f32>,
};

@group(0) @binding(0) var<uniform> object_to_clip: mat4x4<f32>;
@group(0) @binding(0) var<storage, read> instances: array<Instance>;
@vertex
fn vs(
    @builtin(instance_index) instanceIndex: u32,
    @location(0) position: vec3<f32>,
    @location(1) normal: vec3<f32>,
) -> VertexOut {
    var output: VertexOut;

    output.position_clip = vec4(position.x * f32(instanceIndex + 1), position.y, position.z, 1.0) * object_to_clip;
    output.color = normal;
    return output;
}

@fragment
fn fs(
    @location(0) color: vec3<f32>,
) -> @location(0) vec4<f32> {
    return vec4(color, 1.0);
}
