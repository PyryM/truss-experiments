$input a_position, a_normal, a_color0
$output v_color

#include "../common/common.sh"

uniform vec4 u_pointParams; // x: point size
void main() {
    vec4 centerPoint = mul(u_modelView, vec4(a_position.xyz, 1.0));
    centerPoint.xy += a_normal.xy * u_pointParams.x;
    centerPoint = mul(u_proj, centerPoint);

    v_color = a_color0;

    gl_Position = centerPoint;
}
