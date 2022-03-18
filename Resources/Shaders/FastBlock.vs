/*
 Copyright (c) 2013 yvt

 This file is part of OpenSpades.

 OpenSpades is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 OpenSpades is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with OpenSpades.  If not, see <http://www.gnu.org/licenses/>.

 */

uniform mat4 projectionViewMatrix;
uniform mat4 viewMatrix;
uniform vec3 chunkPosition;
uniform vec3 viewPos;
uniform float pointSizeFactor;

// --- Vertex attribute ---
// [x, y, z, u]
attribute vec4 positionAttribute;

// [R, G, B, v]
attribute vec4 colorAttribute;

varying vec4 color;
varying vec3 fogDensity;

void PrepareForShadowForMap(vec3 vertexCoord, vec3 fixedVertexCoord, vec3 normal);
vec4 ComputeFogDensity(float sqLength);

void main() {
	vec4 vertexPos = vec4(chunkPosition, 1.0);
	vertexPos.xyz += positionAttribute.xyz + 0.5;

	// calculate effective normal and tangents
	vec3 centerPos = vertexPos.xyz;
	vec3 viewRelPos = centerPos - viewPos;
	vec3 normal = normalize(-viewRelPos);

	gl_Position = projectionViewMatrix * vertexPos;

	// color
	color = colorAttribute;
	color.xyz *= color.xyz; // linearize

	vec4 viewPos = viewMatrix * vertexPos;
	float distance = dot(viewPos.xyz, viewPos.xyz);
	fogDensity = ComputeFogDensity(distance).xyz;

	gl_PointSize = pointSizeFactor / viewPos.z;

	vec3 fixedPosition = centerPos.xyz + normal * 0.77;
	vec3 shadowVertexPos = centerPos.xyz;
	PrepareForShadowForMap(shadowVertexPos, fixedPosition, normal);
}