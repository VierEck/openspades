uniform mat4 projectionViewModelMatrix;
uniform mat4 viewModelMatrix;
uniform mat4 modelMatrix;
uniform vec3 modelOrigin;
uniform vec3 viewOriginVector;

attribute vec3 positionAttribute;

void main() {

	vec4 vertexPos = vec4(positionAttribute.xyz, 1.);
	vertexPos.xyz += modelOrigin;
	gl_Position = projectionViewModelMatrix * vertexPos;
}

