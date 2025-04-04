struct SoundInstanceData {
    offset: u32,
    size: u32,
    current_frame: u32,
    _padding1: u32,
    position: vec3<f32>,
    _padding2: u32,
};

struct GlobalUniform {
    camera_matrix: mat4x4<f32>,
    sound_count: u32,
    _pad1: u32,
    _pad2: u32,
    _pad3: u32,
    sound_instances: array<SoundInstanceData, 16>, // Use your MAX_SOUND_COUNT here
};

struct VertexOut {
    @builtin(position) position_clip: vec4<f32>,
}

@group(0) @binding(0) var<uniform> global: GlobalUniform;
@vertex
fn vs(
    @location(0) position: vec3<f32>,
    @location(1) normal: vec3<f32>,
) -> VertexOut {
    var output: VertexOut;
    output.position_clip = vec4(position, 1.0) * global.camera_matrix;
    return output;
}

@fragment
fn fs() -> @location(0) vec4<f32> {
    return vec4(1.0, 1.0, 1.0, 1.0);
}
