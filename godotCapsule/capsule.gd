extends MeshInstance

export var longitudes: int = 32 setget set_longitudes, get_longitudes
export var latitudes: int = 16 setget set_latitudes, get_latitudes
export var rings: int = 0 setget set_rings, get_rings

export var depth: float = 1.0 setget set_depth, get_depth
export var radius: float = 0.5 setget set_radius, get_radius

export (String, "ASPECT", "FIXED", "UNIFORM") var uv_profile: String = "ASPECT" setget set_uv_profile, get_uv_profile

export var axis = Vector3(0.0, 0.6, 0.8)


func get_depth() -> float:
    return depth


func get_latitudes() -> int:
    return latitudes


func get_longitudes() -> int:
    return longitudes


func get_radius() -> float:
    return radius


func get_rings() -> int:
    return rings


func get_uv_profile() -> String:
    return uv_profile


func set_depth(dpth: float):
    depth = max(0.0002, dpth)


func set_latitudes(lats: int):
    latitudes = 2 if (lats < 2) else lats
    if (latitudes % 2) != 0:
        latitudes += 1


func set_longitudes(lons: int):
    longitudes = 3 if (lons < 3) else lons


func set_radius(rad: float):
    radius = max(0.0001, rad)


func set_rings(ring: int):
    rings = 0 if (ring < 0) else ring


func set_uv_profile(profile: String):
    uv_profile = profile


func _ready():
    var arr: Array = gen_capsule(longitudes, latitudes, rings, depth, radius, uv_profile)

    mesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

    var success = ResourceSaver.save("res://capsule.tres", mesh, ResourceSaver.FLAG_COMPRESS)
    print(success)


func _process(delta):
    transform.basis = Basis(axis, delta) * transform.basis


func gen_capsule(
    lons: int = 32,
    lats: int = 16,
    ring: int = 0,
    dpth: float = 1.0,
    rad: float = 0.5,
    profile: String = "ASPECT") -> Array:

    # Validate arguments.
    var verif_rad: float = max(0.0001, rad)
    var verif_depth: float = max(0.0002, dpth)
    var verif_rings: int = 0 if (ring < 0) else ring
    var verif_lons: int = 3 if (lons < 3) else lons

    # Latitudes must be even so that equators can be split.
    var verif_lats: int = 2 if (lats < 2) else lats
    if (verif_lats % 2) != 0:
        verif_lats += 1

    # Preliminary calculations.
    var calc_middle: bool = verif_rings > 0
    # warning-ignore:integer_division
    var half_lats: int = verif_lats / 2
    var half_lats_n1: int = half_lats - 1
    var half_lats_n2: int = half_lats - 2
    var rings_p1: int = verif_rings + 1
    var lons_p1: int = verif_lons + 1
    var half_depth: float = verif_depth * 0.5
    var summit: float = half_depth + verif_rad

    # Vertex index offsets.
    var vert_offset_north_hemi: int = verif_lons
    var vert_offset_north_equator: int = vert_offset_north_hemi + lons_p1 * half_lats_n1
    var vert_offset_cylinder: int = vert_offset_north_equator + lons_p1
    var vert_offset_south_equator: int = (vert_offset_cylinder + lons_p1 * rings) \
        if calc_middle else vert_offset_cylinder
    var vert_offset_south_hemi: int = vert_offset_south_equator + lons_p1
    var vert_offset_south_polar: int = vert_offset_south_hemi + lons_p1 * half_lats_n2
    var vert_offset_south_cap: int = vert_offset_south_polar + lons_p1

    # Create arrays.
    var vs: PoolVector3Array = PoolVector3Array()
    var vts: PoolVector2Array = PoolVector2Array()
    var vns: PoolVector3Array = PoolVector3Array()

    # Set arrays to a fixed length.
    var vert_len: int = vert_offset_south_cap + verif_lons
    vs.resize(vert_len)
    vts.resize(vert_len)
    vns.resize(vert_len)

    var to_theta: float = TAU / verif_lons
    var to_phi: float = PI / verif_lats
    var to_tex_horizontal: float = 1.0 / verif_lons
    var to_tex_vertical: float = 1.0 / half_lats

    # Calculate positions for texture coordinates vertical.
    var vt_aspect_ratio: float = 1.0 / 3.0
    if profile == "ASPECT":
        vt_aspect_ratio = verif_rad / (verif_depth + verif_rad * 2.0)
    elif profile == "UNIFORM":
        vt_aspect_ratio = float(half_lats) / (rings_p1 + verif_lats)
    var vt_aspect_north: float = vt_aspect_ratio
    var vt_aspect_south: float = 1.0 - vt_aspect_ratio

    # Cache results that will be reused.
    var theta_cartesian: PoolVector2Array = PoolVector2Array()
    var rho_theta_cartesian: PoolVector2Array = PoolVector2Array()
    var s_texture_cache: PoolRealArray = PoolRealArray()

    theta_cartesian.resize(verif_lons)
    rho_theta_cartesian.resize(verif_lons)
    s_texture_cache.resize(lons_p1)

    # Ranges.
    var lons_range: Array = range(0, verif_lons, 1)
    var lons_p1_range: Array = range(0, lons_p1, 1)
    var hemi_range: Array = range(0, half_lats_n1, 1)

    # Polar vertices.
    for j in lons_range:
        var s_texture_polar: float = (j + 0.5) * to_tex_horizontal
        var theta: float = j * to_theta

        var cos_theta: float = cos(theta)
        var sin_theta: float = sin(theta)

        theta_cartesian[j] = Vector2(cos_theta, sin_theta)
        rho_theta_cartesian[j] = Vector2(
            verif_rad * cos_theta,
            verif_rad * sin_theta)

        # North.
        vs[j] = Vector3(0.0, summit, 0.0)
        vts[j] = Vector2(s_texture_polar, 0.0)
        vns[j] = Vector3(0.0, 1.0, 0.0)

        # South.
        var idx: int = vert_offset_south_cap + j
        vs[idx] = Vector3(0.0, -summit, 0.0)
        vts[idx] = Vector2(s_texture_polar, 1.0)
        vns[idx] = Vector3(0.0, -1.0, 0.0)

    # Equatorial vertices.
    for j in lons_p1_range:
        var s_texture: float = j * to_tex_horizontal
        s_texture_cache[j] = s_texture

        # Wrap to first element upon reaching last.
        var j_mod: int = j % verif_lons
        var tc: Vector2 = theta_cartesian[j_mod]
        var rtc: Vector2 = rho_theta_cartesian[j_mod]

        # North equator.
        var idxn: int = vert_offset_north_equator + j
        vs[idxn] = Vector3(rtc.x, half_depth, -rtc.y)
        vts[idxn] = Vector2(s_texture, vt_aspect_north)
        vns[idxn] = Vector3(tc.x, 0.0, -tc.y)

        # South equator.
        var idxs: int = vert_offset_south_equator + j
        vs[idxs] = Vector3(rtc.x, -half_depth, -rtc.y)
        vts[idxs] = Vector2(s_texture, vt_aspect_south)
        vns[idxs] = Vector3(tc.x, 0.0, -tc.y)

    # Hemisphere vertices.
    for i in hemi_range:
        var ip1f: float = i + 1.0
        var phi: float = ip1f * to_phi

        # For coordinates.
        var cos_phi_south: float = cos(phi)
        var sin_phi_south: float = sin(phi)

        # Symmetrical hemispheres mean cosine and sine only need
        # to be calculated once.
        var cos_phi_north: float = sin_phi_south
        var sin_phi_north: float = -cos_phi_south

        var rho_cos_phi_north: float = verif_rad * cos_phi_north
        var rho_sin_phi_north: float = verif_rad * sin_phi_north
        var z_offset_north: float = half_depth - rho_sin_phi_north

        var rho_cos_phi_south: float = verif_rad * cos_phi_south
        var rho_sin_phi_south: float = verif_rad * sin_phi_south
        var z_offset_south: float = -half_depth - rho_sin_phi_south

        var t_tex_fac: float = ip1f * to_tex_vertical
        var cmpl_tex_fac: float = 1.0 - t_tex_fac
        var t_tex_north: float = t_tex_fac * vt_aspect_north
        var t_tex_south: float = vt_aspect_south * cmpl_tex_fac + t_tex_fac

        var i_lons_p1: int = i * lons_p1
        var vert_curr_lat_north: int = vert_offset_north_hemi + i_lons_p1
        var vert_curr_lat_south: int = vert_offset_south_hemi + i_lons_p1

        for j in lons_p1_range:
            var j_mod: int = j % verif_lons
            var s_texture: float = s_texture_cache[j]
            var tc: Vector2 = theta_cartesian[j_mod]

            # North hemisphere.
            var idxn: int = vert_curr_lat_north + j
            vs[idxn] = Vector3(
                rho_cos_phi_north * tc.x,
                z_offset_north,
                -rho_cos_phi_north * tc.y)
            vts[idxn] = Vector2(s_texture, t_tex_north)
            vns[idxn] = Vector3(
                cos_phi_north * tc.x,
                -sin_phi_north,
                -cos_phi_north * tc.y)

            # South hemisphere.
            var idxs: int = vert_curr_lat_south + j
            vs[idxs] = Vector3(
                rho_cos_phi_south * tc.x,
                z_offset_south,
                -rho_cos_phi_south * tc.y)
            vts[idxs] = Vector2(s_texture, t_tex_south)
            vns[idxs] = Vector3(
                cos_phi_south * tc.x,
                -sin_phi_south,
                -cos_phi_south * tc.y)

    # Cylinder vertices.
    if calc_middle:
        # Exclude both origin and destination edges
        # (North and South equators) from the interpolation.
        var to_fac: float = 1.0 / rings_p1
        var idx_cyl_lat: int = vert_offset_cylinder
        var cyl_range: Array = range(1, rings_p1, 1)

        for h in cyl_range:
            var fac: float = h * to_fac
            var cmpl_fac: float = 1.0 - fac
            var t_texture: float = cmpl_fac * vt_aspect_north + \
                fac * vt_aspect_south
            var z: float = half_depth - verif_depth * fac

            for j in lons_p1_range:
                var j_mod: int = j % verif_lons
                var s_texture: float = s_texture_cache[j]
                var tc: Vector2 = theta_cartesian[j_mod]
                var rtc: Vector2 = rho_theta_cartesian[j_mod]

                vs[idx_cyl_lat] = Vector3(rtc.x, z, -rtc.y)
                vts[idx_cyl_lat] = Vector2(s_texture, t_texture)
                vns[idx_cyl_lat] = Vector3(tc.x, 0.0, -tc.y)

                idx_cyl_lat += 1

    # Triangle indices.
    # Stride is 3 for polar triangles;
    # stride is 6 for two triangles forming a quad.
    var lons_3: int = verif_lons * 3
    var lons_6: int = verif_lons * 6
    var hemi_lons: int = half_lats_n1 * lons_6

    var tri_offset_north_hemi: int = lons_3
    var tri_offset_cylinder: int = tri_offset_north_hemi + hemi_lons
    var tri_offset_south_hemi: int = tri_offset_cylinder + rings_p1 * lons_6
    var tri_offset_south_cap: int = tri_offset_south_hemi + hemi_lons

    var fs_len: int = tri_offset_south_cap + lons_3
    var tris: PoolIntArray = PoolIntArray()
    tris.resize(fs_len)

    # Polar caps.
    var k: int = 0
    var m: int = tri_offset_south_cap
    for i in lons_range:

        # North.
        tris[k] = i
        tris[k + 1] = vert_offset_north_hemi + i + 1
        tris[k + 2] = vert_offset_north_hemi + i

        # South.
        tris[m] = vert_offset_south_cap + i
        tris[m + 1] = vert_offset_south_polar + i
        tris[m + 2] = vert_offset_south_polar + i + 1

        k += 3
        m += 3

    # Hemispheres.
    k = tri_offset_north_hemi
    m = tri_offset_south_hemi
    for i in hemi_range:
        var i_lons_p1: int = i * lons_p1

        var vert_curr_lat_north: int = vert_offset_north_hemi + i_lons_p1
        var vert_next_lat_north: int = vert_curr_lat_north + lons_p1

        var vert_curr_lat_south: int = vert_offset_south_equator + i_lons_p1
        var vert_next_lat_south: int = vert_curr_lat_south + lons_p1

        for j in lons_range:

            # North.
            var north00: int = vert_curr_lat_north + j
            var north01: int = vert_next_lat_north + j
            var north11: int = vert_next_lat_north + j + 1
            var north10: int = vert_curr_lat_north + j + 1

            tris[k] = north00
            tris[k + 1] = north10
            tris[k + 2] = north11

            tris[k + 3] = north00
            tris[k + 4] = north11
            tris[k + 5] = north01

            # South.
            var south00: int = vert_curr_lat_south + j
            var south01: int = vert_next_lat_south + j
            var south11: int = vert_next_lat_south + j + 1
            var south10: int = vert_curr_lat_south + j + 1

            tris[m] = south00
            tris[m + 1] = south10
            tris[m + 2] = south11

            tris[m + 3] = south00
            tris[m + 4] = south11
            tris[m + 5] = south01

            k += 6
            m += 6

    # Cylinder.
    k = tri_offset_cylinder
    var tri_cyl_range: Array = range(0, rings_p1, 1)
    for i in tri_cyl_range:
        var vert_curr_lat: int = vert_offset_north_equator + i * lons_p1
        var vert_next_lat: int = vert_curr_lat + lons_p1

        for j in lons_range:
            var cy00: int = vert_curr_lat + j
            var cy01: int = vert_next_lat + j
            var cy11: int = vert_next_lat + j + 1
            var cy10: int = vert_curr_lat + j + 1

            tris[k] = cy00
            tris[k + 1] = cy10
            tris[k + 2] = cy11

            tris[k + 3] = cy00
            tris[k + 4] = cy11
            tris[k + 5] = cy01

            k += 6

    var arr: Array = Array()
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = vs
    arr[Mesh.ARRAY_TEX_UV] = vts
    arr[Mesh.ARRAY_NORMAL] = vns
    arr[Mesh.ARRAY_INDEX] = tris
    return arr
