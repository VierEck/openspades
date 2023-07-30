uniform mat4 projectionViewModelMatrix;
uniform vec3 modelOrigin;
uniform mat4 modelMatrix;
uniform vec3 viewOriginVector;

attribute vec3 positionAttribute;
varying float distanceSquare;

void main() {
	
	vec4 vertexPos = vec4(positionAttribute.xyz, 1.0);
	vertexPos.xyz += modelOrigin;
	gl_Position = projectionViewModelMatrix * vertexPos;
	
	vec2 horzRelativePos = (modelMatrix * vertexPos).xy - viewOriginVector.xy;
	distanceSquare = dot(horzRelativePos, horzRelativePos);
}

