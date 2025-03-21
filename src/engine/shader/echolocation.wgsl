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
@group(0) @binding(1) var<storage, read> instances: array<Instance>;
@vertex
fn vs(
    @builtin(instance_index) instanceIndex: u32,
    @location(0) position: vec3<f32>,
    @location(1) normal: vec3<f32>,
) -> VertexOut {
    var output: VertexOut;

    // Get instance data
    let instance = instances[instanceIndex];

    // Apply instance transformation
    // 1. Scale the vertex position
    var transformed_position = position * instance.scale;

    // 2. Apply rotation using quaternion
    transformed_position = quat_rotate(instance.rotation, transformed_position);

    // 3. Translate the vertex position
    transformed_position = transformed_position + instance.position;

    // 4. Apply the camera/projection transformation
    output.position_clip = vec4(transformed_position, 1.0) * object_to_clip;

    output.color = normal;
    return output;
}

@fragment
fn fs(
    @location(0) color: vec3<f32>,
) -> @location(0) vec4<f32> {
    return vec4(color, 1.0);
}

// Apply quaternion rotation to a vector
fn quat_rotate(q: vec4<f32>, v: vec3<f32>) -> vec3<f32> {
    // Extract the vector part of the quaternion
    let u = q.xyz;
    // Extract the scalar part of the quaternion
    let s = q.w;

    // Formula: v' = v + 2 * cross(u, cross(u, v) + s*v)
    return v + 2.0 * cross(u, cross(u, v) + s * v);
}
