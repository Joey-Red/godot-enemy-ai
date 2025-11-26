shader_type spatial;
render_mode diffuse_toon, specular_toon; // Use Godot's built-in toon modes as a base

// --- INPUTS ---
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color;
uniform sampler2D metallic_texture : source_color, hint_default_black;
uniform sampler2D roughness_texture : source_color, hint_default_white;

// --- TOON SETTINGS ---
group_uniforms Toon_Settings;
uniform vec4 shade_color : source_color = vec4(0.5, 0.5, 0.6, 1.0); // The color of the shadow
uniform float shade_threshold : hint_range(-1.0, 1.0) = 0.0; // Where light turns to shadow
uniform float shade_softness : hint_range(0.0, 1.0) = 0.05; // Softness of the edge

group_uniforms Rim_Light;
uniform bool enable_rim = true;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.5;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.2;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// 1. Apply Textures
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb * albedo_color.rgb;
	
	METALLIC = texture(metallic_texture, UV).r;
	ROUGHNESS = texture(roughness_texture, UV).r;
}

void light() {
	// 1. Calculate NdotL (Angle between Normal and Light)
	// This tells us which part of the model is facing the light
	float dot_product = dot(NORMAL, LIGHT);
	
	// 2. Create the Toon Cut
	// Instead of smooth gradient, we snap from Light to Shadow based on threshold
	float shadow_mask = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, dot_product);
	
	// 3. Calculate Final Diffuse
	// Mix between the Shadow Color and Light Color based on the mask
	vec3 toon_lighting = mix(shade_color.rgb * ALBEDO, LIGHT_COLOR * ALBEDO * ATTENUATION, shadow_mask);
	
	// 4. Rim Light (The glowing edge effect seen in Zelda)
	if (enable_rim) {
		float view_dot = dot(NORMAL, VIEW); // Angle to camera
		float rim_intensity = 1.0 - view_dot; // Edges are 1.0
		
		// Only show rim on the lit side (optional, looks better)
		float rim_hit = smoothstep(rim_threshold, rim_threshold + 0.1, rim_intensity);
		float rim_on_lit_side = smoothstep(0.0, 0.2, dot_product); 
		
		vec3 rim = rim_color.rgb * rim_amount * rim_hit * rim_on_lit_side * LIGHT_COLOR;
		toon_lighting += rim;
	}
	
	// 5. Apply Specular (Shiny spots)
	// We sharpen the specular to make it look anime-like
	vec3 half_vector = normalize(VIEW + LIGHT);
	float NdotH = max(0.0, dot(NORMAL, half_vector));
	float specular_intensity = pow(NdotH, (1.0 - ROUGHNESS) * 100.0); // Sharpness based on roughness
	specular_intensity = smoothstep(0.5, 0.55, specular_intensity); // Hard cut specular
	
	vec3 specular_light = LIGHT_COLOR * specular_intensity * METALLIC;

	// 6. Output
	DIFFUSE_LIGHT += toon_lighting;
	SPECULAR_LIGHT += specular_light;
}