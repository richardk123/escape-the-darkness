const MAX_SOUND_COUNT = 16;
const SOUND_SPEED = 300.0; // meters per second
const SAMPLE_RATE = 48000.0; // samples per second
const SOUND_BRIGHTNESS = 100.0;
const SOUND_PROPAGATION_QUADRATIC = 0.02;
const DISPLACEMENT_SCALE = 2; // Controls the strength of vertex displacement

struct SoundInstanceData {
    offset: u32,
    size: u32,
    current_frame: u32,
    _padding1: u32,
    position: vec3<f32>,
    _padding2: u32,
    color: vec3<f32>,
    _padding3: u32,
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
    @location(0) @interpolate(linear) world_position: vec3<f32>,
    @location(1) @interpolate(linear) normal: vec3<f32>,
    @location(2) @interpolate(linear) barycentric: vec3<f32>,
    @location(3) @interpolate(linear) view_position: vec3<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var<storage, read> instances: array<Instance>;
@group(0) @binding(2) var image: texture_2d<f32>;
@group(0) @binding(3) var image_sampler: sampler;
@group(0) @binding(4) var normal_map: texture_2d<f32>;
@group(0) @binding(5) var normal_map_sampler: sampler;

fn getSoundIntensity(sound: SoundInstanceData, distance: f32) -> f32 {
    // Calculate time delay in samples
    let delay_samples = (distance / SOUND_SPEED) * SAMPLE_RATE;

    // Calculate the effective frame we should sample from
    // We need to look at earlier samples for more distant points
    let current_frame = sound.current_frame;
    let delay_frames = u32(delay_samples);

    // Safely calculate the frame to sample (prevent underflow)
    var sample_frame: u32;
    if (current_frame > delay_frames) {
        sample_frame = current_frame - delay_frames;
    } else {
        return 0;
    }

    // Frame exceeded the size
    if (sample_frame > sound.size) {
        return 0;
    }

    // Calculate the texture dimensions
    let texture_size = i32(textureDimensions(image).x);

    // Calculate sample position in the byte array
    let sample_position = sound.offset + (sample_frame % sound.size);

    // Since each texel holds 4 bytes, divide by 4 to get texel index
    let texel_index = sample_position / 4u;

    // Calculate which component we need (0=R, 1=G, 2=B, 3=A)
    let component_index = sample_position % 4u;

    // Calculate 2D texel coordinates
    let texel_x = i32(texel_index % u32(texture_size));
    let texel_y = i32(texel_index / u32(texture_size));

    // Early return for out-of-bounds access
    if (texel_x < 0 || texel_x >= texture_size || texel_y < 0 || texel_y >= texture_size) {
        return 0.0;
    }

    // Load the texel
    let texel = textureLoad(image, vec2<i32>(texel_x, texel_y), 0);

    // Select the correct component (R, G, B, or A)
    var raw_value: f32;
    switch(component_index) {
        case 0u: { raw_value = texel.r; }
        case 1u: { raw_value = texel.g; }
        case 2u: { raw_value = texel.b; }
        case 3u: { raw_value = texel.a; }
        default: { raw_value = 0.0; }
    }
    // Filter low values
    if (raw_value < 0.01) {
        return 0;
    }

    // Convert from normalized [0,1] to intensity
    return raw_value;
}

@vertex
fn vs(
    @builtin(instance_index) instanceIndex: u32,
    @builtin(vertex_index) vertexIndex: u32,
    @location(0) position: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
    @location(3) tangent: vec4<f32>,
    @location(4) barycentric: vec3<f32>,
) -> VertexOut {
    let instance = instances[instanceIndex];

    // Transform vertex position to world space before displacement
    let initialWorldPos = (instance.model_matrix * vec4<f32>(position, 1.0)).xyz;

    // Calculate displacement from all sound sources
    var displacement = vec3<f32>(0.0);
    var totalIntensity = 0.0;

    for (var i: u32 = 0; i < uniforms.sound_count; i++) {
        let sound = uniforms.sound_instances[i];
        let distance = length(sound.position - initialWorldPos) +
                      length(initialWorldPos - uniforms.camera_position);

        if (distance > 0.001) { // Avoid division by zero
            let sound_dir = normalize(initialWorldPos - sound.position);
            let sound_intensity = getSoundIntensity(sound, distance);

            // Calculate base attenuation
            let attenuation = SOUND_BRIGHTNESS * sound_intensity /
                            (SOUND_PROPAGATION_QUADRATIC * distance * distance);

            // Approximate tone mapping (Reinhard) for the displacement magnitude
            // This mimics how the fragment shader will tone-map the colors
            let tone_mapped = attenuation / (attenuation + 1.0);

            // Approximate gamma correction
            let gamma_corrected = pow(tone_mapped, 1.0/2.2);

            // Apply the processed value for displacement
            let displacement_factor = gamma_corrected * DISPLACEMENT_SCALE;

            // Add this sound's contribution to total displacement
            displacement += sound_dir * displacement_factor;
            totalIntensity += displacement_factor;
        }
    }

    // Apply a cap to avoid extreme displacement
    let max_displacement = 5.0;  // Adjust this value as needed
    if (length(displacement) > max_displacement) {
        displacement = normalize(displacement) * max_displacement;
    }

    // Apply displacement to world position
    let displacedWorldPos = initialWorldPos + displacement;

    // Transform back to model space (unnecessary in this case since we're working in world space)
    // And then continue with the normal pipeline
    let viewPos = uniforms.view_matrix * vec4<f32>(displacedWorldPos, 1.0);
    let clipPos = uniforms.projection_matrix * viewPos;

    var output: VertexOut;
    output.position = clipPos;
    output.world_position = displacedWorldPos;
    output.view_position = viewPos.xyz;
    output.normal = normalize(normal * mat3x3(
         instance.model_matrix[0].xyz,
         instance.model_matrix[1].xyz,
         instance.model_matrix[2].xyz,
    ));
    output.barycentric = barycentric;
    return output;
}

@fragment
fn fs(in: VertexOut) -> @location(0) vec4<f32> {
    var n = normalize(in.normal);

    let view_dir = normalize(uniforms.camera_position - in.world_position);
    var result = vec3<f32>(0.0);

    for (var i: u32 = 0; i < uniforms.sound_count; i++) {
        let sound = uniforms.sound_instances[i];
        let sound_color = sound.color;
        let sound_dir = normalize(sound.position - in.world_position);
        let distance = length(sound.position - in.world_position) +
                      length(in.world_position - uniforms.camera_position);
        let sound_intensity = getSoundIntensity(sound, distance);

        // Calculate attenuation based on total sound travel distance
        let attenuation = SOUND_BRIGHTNESS * sound_intensity /
                         (SOUND_PROPAGATION_QUADRATIC * distance * distance);

        // Calculate how much sound energy gets reflected toward camera
        let reflection_factor = max(dot(n, view_dir), 0.0);
        let diffuse = max(dot(n, sound_dir), 0.0);
        result += diffuse * attenuation * sound_color;
    }

    // Apply tone mapping and gamma correction
    result = result / (result + vec3<f32>(1.0)); // Simple Reinhard tone mapping
    result = pow(result, vec3<f32>(1.0/2.2));    // Gamma correction
    let distance = distance(in.view_position, uniforms.camera_position);

    // wireframe
    let barys = in.barycentric;
    let deltas = fwidth(barys);
    let smoothing = deltas * 1.0;
    let thickness = deltas * 10.75 * (1 / distance);

    // Create a wireframe effect with thickness control
    let thresholds = smoothing + thickness;
    let smoothedges = smoothstep(thickness, thresholds, barys);
    let edge = min(min(smoothedges.x, smoothedges.y), smoothedges.z);

    // Change this to make wireframes more visible
    let wireframe_color = result + result * vec3<f32>(0.5);
    let final_color = mix(wireframe_color, result, edge);
    return vec4(final_color, 1.0);
}
