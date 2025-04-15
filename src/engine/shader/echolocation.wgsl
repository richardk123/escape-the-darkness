struct SoundInstanceData {
    offset: u32,
    size: u32,
    current_frame: u32,
    _padding1: u32,
    position: vec3<f32>,
    _padding2: u32,
};

struct GlobalUniform {
    world_to_clip: mat4x4<f32>,
    object_to_world: mat4x4<f32>,
    camera_position: vec3<f32>,
    sound_count: u32,
    sound_instances: array<SoundInstanceData, 16>, // Use your MAX_SOUND_COUNT here
};

struct Instance {
    position: vec3<f32>,
    rotation: vec4<f32>,
    scale: vec3<f32>,
};

struct VertexOut {
    @builtin(position) position_clip: vec4<f32>,
    @location(0) normal: vec3<f32>,
    @location(1) world_pos: vec3<f32>,
    @location(2) uv: vec2<f32>,          // UV coordinates
    @location(3) tangent: vec3<f32>,    // Tangent in world space
    @location(4) bitangent: vec3<f32>,   // Tangent with handedness
}

@group(0) @binding(0) var<uniform> global: GlobalUniform;
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
    var output: VertexOut;

    // Get instance data
    let instance = instances[instanceIndex];

    // Calculate sound-based scaling factor
    let sound_scale_factor = calculateSoundScaleFactor(instance.position);

    // Apply instance transformation with sound-based scaling
    // 1. Scale the vertex position - now with additional sound-based scaling
    var transformed_position = position * instance.scale;
    // transformed_position.y += sound_scale_factor;

    // 2. Apply rotation using quaternion
    transformed_position = quat_rotate(instance.rotation, transformed_position);

    // Transform normal and tangent
    var transformed_normal = quat_rotate(instance.rotation, normal);
    var transformed_tangent_xyz = quat_rotate(instance.rotation, tangent.xyz);
    let transformed_tangent = vec4<f32>(transformed_tangent_xyz, tangent.w);

    // Convert to world space
    let normal_ws = normalize((global.object_to_world * vec4<f32>(transformed_normal, 0.0)).xyz);
    let tangent_ws = normalize((global.object_to_world * vec4<f32>(transformed_tangent_xyz, 0.0)).xyz);

    // Calculate bitangent in world space (preserving handedness from tangent.w)
    let bitangent_ws = normalize(cross(normal_ws, tangent_ws) * tangent.w);

    // 3. Translate the vertex position
    transformed_position = transformed_position + instance.position;

    // 4. Apply the camera/projection transformation
    output.position_clip = vec4(transformed_position, 1.0) * global.world_to_clip;

    // Pass world position and normal to fragment shader
    output.world_pos = transformed_position;
    output.normal = normal_ws;
    output.uv = uv;
    output.tangent = tangent_ws;
    output.bitangent = bitangent_ws;
    return output;
}

@group(0) @binding(2) var image: texture_2d<f32>;
@group(0) @binding(3) var image_sampler: sampler;
@group(0) @binding(4) var normal_map: texture_2d<f32>;
@group(0) @binding(5) var normal_map_sampler: sampler;
@fragment
fn fs(
    @location(0) normal: vec3<f32>,
    @location(1) world_pos: vec3<f32>,
    @location(2) uv: vec2<f32>,
    @location(3) tangent: vec3<f32>,
    @location(4) bitangent: vec3<f32>
) -> @location(0) vec4<f32> {

    // Construct the TBN matrix in the fragment shader
    let TBN = mat3x3<f32>(
        tangent,
        bitangent,
        normal
    );

    // Tiling for visual detail
    let tiled_uv = fract(uv * 6.0);
    let sampled_normal = textureSample(normal_map, normal_map_sampler, tiled_uv).xyz * 2.0 - 1.0;
    let world_normal = normalize(TBN * sampled_normal);

    return vec4<f32>(world_normal * 0.5 + 0.5, 1.0);

    // // Base material properties
    // let material_diffuse = vec3<f32>(0.8, 0.9, 1.0); // Bluish material
    // let material_specular = vec3<f32>(1.0);
    // let material_shininess = 2.0;
    // let ambient_factor = 0.0;

    // // Initialize ambient component
    // var result = ambient_factor * material_diffuse;

    // let view_dir = normalize(global.camera_position - world_pos);

    // // Process each sound as a point light
    // for (var i: u32 = 0; i < global.sound_count; i++) {
    //     let sound = global.sound_instances[i];

    //     // Create a point light from the sound
    //     let sound_source = SoundSource(
    //         sound.position,               // position
    //         vec3<f32>(0.8, 0.9, 1.0),     // color
    //         100.0,                          // intensity
    //         3000.0,                        // range
    //         1.0,                          // constant
    //         0.5,                         // linear
    //         0.001                         // quadratic
    //     );

    //     // Add light contribution
    //     result += calculateEcholocation(
    //         sound_source,
    //         sound,
    //         world_pos,
    //         world_normal,
    //         view_dir,
    //         material_diffuse,
    //         material_specular,
    //         material_shininess
    //     );
    // }

    // // Apply tone mapping and gamma correction
    // result = result / (result + vec3<f32>(1.0)); // Simple Reinhard tone mapping
    // result = pow(result, vec3<f32>(1.0/2.2));    // Gamma correction

    // return vec4<f32>(result, 1.0);
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

struct SoundSource {
    position: vec3<f32>,
    color: vec3<f32>,
    intensity: f32,
    range: f32,
    // Optional: attenuation factors
    constant: f32,
    linear: f32,
    quadratic: f32,
}

fn calculateEcholocation(sound_source: SoundSource, sound: SoundInstanceData,
                         fragment_position: vec3<f32>, normal: vec3<f32>,
                         view_direction: vec3<f32>, material_diffuse: vec3<f32>,
                         material_specular: vec3<f32>, shininess: f32) -> vec3<f32> {
    // Calculate sound direction and distances
    let sound_dir = normalize(sound_source.position - fragment_position);

    // Distance from sound source to fragment AND from fragment to camera
    // This models the round-trip of the sound wave
    let distance = length(sound_source.position - fragment_position) +
                  length(fragment_position - global.camera_position);

    // // Check if fragment is within detectable range
    // if (distance > sound_source.range) {
    //     return vec3<f32>(0.0);
    // }

    // Calculate sound intensity from texture
    let sound_intensity = getSoundIntensity(sound, distance);

    // Calculate attenuation based on total sound travel distance
    let attenuation = sound_source.intensity * sound_intensity /
                    (sound_source.constant + sound_source.linear * distance +
                     sound_source.quadratic * distance * distance);

    // Calculate how much sound energy gets reflected toward camera
    // The angle between normal and view direction affects this
    let reflection_factor = max(dot(normal, view_direction), 0.0);

    // Use diffuse component to model omnidirectional scattering of sound
    let diff = max(dot(normal, sound_dir), 0.0);
    let diffuse = diff * material_diffuse;

    // We can keep specular to represent sharper reflections off flat surfaces
    // (like how sound bounces more directionally off flat walls)
    let reflect_dir = reflect(-sound_dir, normal);
    let spec = pow(max(dot(view_direction, reflect_dir), 0.0), shininess);
    let specular = spec * material_specular;

    // Return the combined effect, influenced by reflection factor
    return (diffuse + specular) * attenuation * sound_source.color * reflection_factor;
}

// Updated function with distance parameter
fn getSoundIntensity(sound: SoundInstanceData, distance: f32) -> f32 {
    const SOUND_SPEED = 300.0; // meters per second
    const SAMPLE_RATE = 48000.0; // samples per second

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
        sample_frame = 0u;
    }
    // Calculate the texture dimensions
    let texture_width = i32(textureDimensions(image).x);
    let texture_height = i32(textureDimensions(image).y);

    // Calculate sample position in the byte array
    let sample_position = sound.offset + (sample_frame % sound.size);

    // Since each texel holds 4 bytes, divide by 4 to get texel index
    let texel_index = sample_position / 4u;

    // Calculate which component we need (0=R, 1=G, 2=B, 3=A)
    let component_index = sample_position % 4u;

    // Calculate 2D texel coordinates
    let texel_x = i32(texel_index % u32(texture_width));
    let texel_y = i32(texel_index / u32(texture_width));

    // Early return for out-of-bounds access
    if (texel_x < 0 || texel_x >= texture_width || texel_y < 0 || texel_y >= texture_height) {
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


// Function to displace vertices based on sound
fn applySoundDisplacement(position: vec3<f32>, normal: vec3<f32>) -> vec3<f32> {
    var displaced_position = position;
    var total_displacement_factor = 0.0;

    // Process each sound source
    for (var i: u32 = 0; i < global.sound_count; i++) {
        let sound = global.sound_instances[i];

        // Calculate distance from vertex to sound source
        let distance_to_sound = length(sound.position - position);

        // Skip if too far
        if (distance_to_sound > 300.0) {
            continue;
        }

        // Get sound intensity based on distance
        let intensity = getSoundIntensity(sound, distance_to_sound);

        // Calculate displacement amount
        // - Decreases with distance
        // - Increases with sound intensity
        let displacement_factor = intensity * max(0.0, 1.0 - distance_to_sound / 300.0);

        // Accumulate displacement factor from all sounds
        total_displacement_factor += displacement_factor;
    }

    // Calculate displacement direction from center to vertex
    // Note: Since we're working in local space before instance transforms,
    // the direction from center is just the position itself
    let direction_from_center = normalize(position);

    // Apply displacement along direction from center
    let displacement_scale = 2.0; // Adjust this value for stronger/weaker effect
    displaced_position += direction_from_center * total_displacement_factor * displacement_scale;

    return displaced_position;
}

// New function to calculate sound-based scaling
fn calculateSoundScaleFactor(position: vec3<f32>) -> f32 {
    var total_scale_factor = 0.0;

    // Process each sound source
    for (var i: u32 = 0; i < global.sound_count; i++) {
        let sound = global.sound_instances[i];

        // Calculate distance from object to sound source
        let distance_to_sound = length(sound.position - position);

        // Skip if too far
        if (distance_to_sound > 300.0) {
            continue;
        }

        // Get sound intensity based on distance
        let intensity = getSoundIntensity(sound, distance_to_sound);

        // Calculate scale amount
        // - Decreases with distance
        // - Increases with sound intensity
        let scale_factor = intensity * max(0.0, 1.0 - distance_to_sound / 300.0);

        // Accumulate scale factor from all sounds
        total_scale_factor += scale_factor;
    }

    // Limit maximum scale and apply scale multiplier
    let scale_multiplier = 0.5; // Adjust this for stronger/weaker scaling
    return min(total_scale_factor * scale_multiplier, 2.0); // Maximum 2x scaling
}
