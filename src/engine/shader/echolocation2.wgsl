const MAX_SOUND_COUNT = 16;

struct SoundInstanceData {
    offset: u32,
    size: u32,
    current_frame: u32,
    _padding1: u32,
    position: vec3<f32>,
    _padding2: u32,
};

struct Instance {
    model_matrix: mat4x4<f32>,    // Precomputed model matrix
    // normal_matrix: mat4x4<f32>,   // Precomputed normal matrix
};

struct Uniforms {
    view_matrix: mat4x4<f32>,        // Camera view matrix
    projection_matrix: mat4x4<f32>,  // Projection matrix
    camera_position: vec3<f32>,
    sound_count: u32,
    sound_instances: array<SoundInstanceData, MAX_SOUND_COUNT>,
};

struct VertexOut {
    @builtin(position) position: vec4<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var<storage, read> instances: array<Instance>;
@vertex
fn vs(
    @builtin(instance_index) instanceIndex: u32,
    @builtin(vertex_index) vertexIndex: u32,
    @location(0) position: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
    @location(3) tangent: vec4<f32>,
) -> VertexOut {
    // Get instance data
    let instance = instances[instanceIndex];
    let worldPos = instance.model_matrix * vec4<f32>(position, 1.0);
    let viewPos = uniforms.view_matrix * worldPos;
    let clipPos = uniforms.projection_matrix * viewPos;

    var output: VertexOut;
    output.position = clipPos;
    return output;
}

@fragment
fn fs() -> @location(0) vec4<f32> {
    return vec4<f32>(1.0);
}
