const MAX_SOUND_COUNT = 16;

struct SoundInstanceData {
    offset: u32,
    size: u32,
    current_frame: u32,
    _padding1: u32,
    position: vec3<f32>,
    _padding2: u32,
};

struct Uniforms {
    view_matrix: mat4x4<f32>,        // Camera view matrix
    projection_matrix: mat4x4<f32>,  // Projection matrix
    camera_position: vec3<f32>,
    sound_count: u32,
    sound_instances: array<SoundInstanceData, MAX_SOUND_COUNT>,
};

struct Instance {
    model_matrix: mat4x4<f32>,    // Precomputed model matrix
};

struct VertexOut {
    @builtin(position) position_clip: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var<storage, read> instances: array<Instance>;
@vertex
fn vs(
    @builtin(instance_index) instanceIndex: u32,
    @location(0) position: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
    @location(3) tangent: vec4<f32>,
) -> VertexOut {
    let instance = instances[instanceIndex];
    let clip_pos = uniforms.projection_matrix * uniforms.view_matrix * instance.model_matrix * vec4<f32>(position, 1.0);

    var output: VertexOut;
    output.position_clip = clip_pos;
    output.uv = uv;
    return output;
}

@group(0) @binding(2) var image: texture_2d<f32>;
@group(0) @binding(3) var image_sampler: sampler;
@fragment
fn fs(
    @location(0) uv: vec2<f32>,
) -> @location(0) vec4<f32> {
    return textureSample(image, image_sampler, uv);// sample from the texture
}
