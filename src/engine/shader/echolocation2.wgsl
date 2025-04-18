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
    @location(0) world_position: vec3<f32>,
    @location(1) normal: vec3<f32>,
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
    output.world_position = worldPos.xyz;
    output.normal = normal * mat3x3(
         instance.model_matrix[0].xyz,
         instance.model_matrix[1].xyz,
         instance.model_matrix[2].xyz,
    );
    return output;
}

@fragment
fn fs(in: VertexOut) -> @location(0) vec4<f32> {
    let light_position = vec3<f32>(0.0);
    let light_color = vec3<f32>(1.0);

    let lightDir = normalize(light_position - in.world_position);
    let diffuse = max(dot(in.normal, lightDir), 0.0);

    let baseColor = vec3<f32>(1.0, 1.0, 1.0); // White base color
    let finalColor = baseColor * light_color * diffuse;

    return vec4<f32>(finalColor, 1.0);
}
