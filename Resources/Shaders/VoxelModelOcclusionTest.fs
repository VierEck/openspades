varying float distanceSquare;

void main() {
	if (distanceSquare > 16384) //128 * 128
		discard; //occluded by fog

	gl_FragColor.rgba = vec4(0.0, 0.0, 0.0, 1.0);
}

