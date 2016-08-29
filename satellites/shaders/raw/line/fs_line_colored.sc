$input v_wpos, v_color // in...

#include "../common/common.sh"

uniform vec4 u_color;

void main()
{
	gl_FragColor = v_color * u_color;
}
