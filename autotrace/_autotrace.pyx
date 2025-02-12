# 'at' is short for 'autotrace' and refers to the C types, structs, and functions.

cimport libc.stdlib
cimport libc.stdio
from ._autotrace cimport *
from .autotrace import Color, Path, Point, Spline, Vector
import numpy as np
from cython.view cimport array as cvarray


# Allocate memory and initialize it to zero.
cdef void *alloc(size_t size):
    cdef void *ptr = libc.stdlib.calloc(1, size)
    if ptr == NULL:
        raise MemoryError()

    return ptr


# Fixes a bug in AutoTrace's at_fitting_opts_free function.
cdef void at_fitting_opts_free(at_fitting_opts_type *opts):
    if opts.background_color != NULL:
        at_color_free(opts.background_color)

    libc.stdlib.free(opts)


# Convert an array object to an at_bitmap struct.
cdef at_bitmap *array_to_at_bitmap(data):
    cdef int height = len(data)
    cdef int width = len(data[0])
    cdef int np = len(data[0][0])

    cdef at_bitmap *bitmap = at_bitmap_new(width, height, np)

    cdef int x, y, p, i = 0
    for y in range(height):
        for x in range(width):
            for p in range(np):
                bitmap.bitmap[i] = data[y][x][p]
                i += 1

    return bitmap


# Convert a TraceOptions object to an at_fitting_opts struct.
cdef at_fitting_opts_type *trace_options_to_at_fitting_opts(options):
    cdef at_fitting_opts_type *opts = at_fitting_opts_new()

    if options.background_color is not None:
        opts.background_color = at_color_new(
            options.background_color.r,
            options.background_color.g,
            options.background_color.b,
        )

    opts.charcode = options.charcode
    opts.color_count = options.color_count
    opts.corner_always_threshold = options.corner_always_threshold
    opts.corner_surround = options.corner_surround
    opts.corner_threshold = options.corner_threshold
    opts.error_threshold = options.error_threshold
    opts.filter_iterations = options.filter_iterations
    opts.line_reversion_threshold = options.line_reversion_threshold
    opts.line_threshold = options.line_threshold
    opts.remove_adjacent_corners = options.remove_adjacent_corners
    opts.tangent_surround = options.tangent_surround
    opts.despeckle_level = options.despeckle_level
    opts.despeckle_tightness = options.despeckle_tightness
    opts.noise_removal = options.noise_removal
    opts.centerline = options.centerline
    opts.preserve_width = options.preserve_width
    opts.width_weight_factor = options.width_weight_factor

    return opts


# Convert a Vector object to an at_spline_list_array struct.
cdef at_spline_list_array_type *vector_image_to_at_splines(vector_image):
    at_spline_list_array = <at_spline_list_array_type *>alloc(sizeof(at_spline_list_array_type))

    if vector_image.background_color is not None:
        at_spline_list_array.background_color = at_color_new(
            vector_image.background_color.r,
            vector_image.background_color.g,
            vector_image.background_color.b,
        )

    at_spline_list_array.width = vector_image.width
    at_spline_list_array.height = vector_image.height
    at_spline_list_array.centerline = vector_image.centerline
    at_spline_list_array.preserve_width = vector_image.preserve_width
    at_spline_list_array.width_weight_factor = vector_image.width_weight_factor
    at_spline_list_array.length = len(vector_image)
    at_spline_list_array.data = <at_spline_list_type *>alloc(sizeof(at_spline_list_type) * at_spline_list_array.length)

    cdef int i, j, k
    for i in range(len(vector_image)):
        path = vector_image.paths[i]

        at_spline_list = &at_spline_list_array.data[i]
        at_spline_list.color.r = path.color.r
        at_spline_list.color.g = path.color.g
        at_spline_list.color.b = path.color.b
        at_spline_list.clockwise = path.clockwise
        at_spline_list.open = path.open
        at_spline_list.length = len(path)
        at_spline_list.data = <at_spline_type *>alloc(sizeof(at_spline_type) * at_spline_list.length)

        for j in range(len(path)):
            spline = path.splines[j]

            at_spline = &at_spline_list.data[j]
            at_spline.degree = spline.degree
            at_spline.linearity = spline.linearity

            for k in range(4):
                at_spline.v[k].x = spline.points[k].x
                at_spline.v[k].y = spline.points[k].y
                at_spline.v[k].z = spline.points[k].z

    return at_spline_list_array


# Convert an at_spline_list_array struct to a Vector object.
cdef at_splines_to_vector_image(at_spline_list_array_type *at_spline_list_array):
    if at_spline_list_array.background_color != NULL:
        background_color = Color(
            r=at_spline_list_array.background_color.r,
            g=at_spline_list_array.background_color.g,
            b=at_spline_list_array.background_color.b,
        )
    else:
        background_color = None

    vector_image = Vector(
        paths=[],
        width=at_spline_list_array.width,
        height=at_spline_list_array.height,
        background_color=background_color,
        centerline=at_spline_list_array.centerline,
        preserve_width=at_spline_list_array.preserve_width,
        width_weight_factor=at_spline_list_array.width_weight_factor,
    )

    cdef int i, j, k
    for i in range(at_spline_list_array.length):
        at_spline_list = at_spline_list_array.data[i]

        color = Color(
            r=at_spline_list.color.r,
            g=at_spline_list.color.g,
            b=at_spline_list.color.b,
        )

        path = Path(
            splines=[],
            color=color,
            clockwise=at_spline_list.clockwise,
            open=at_spline_list.open,
        )

        for j in range(at_spline_list.length):
            at_spline = at_spline_list.data[j]

            spline = Spline(
                points=[],
                degree=at_spline.degree,
                linearity=at_spline.linearity,
            )

            for k in range(4):
                point = Point(
                    x=at_spline.v[k].x,
                    y=at_spline.v[k].y,
                    z=at_spline.v[k].z,
                )

                spline.points.append(point)

            path.splines.append(spline)

        vector_image.paths.append(path)

    return vector_image


# Trace a bitmap image.
def trace(data, options = None):
    cdef at_bitmap *bitmap = array_to_at_bitmap(data)
    cdef at_fitting_opts_type *opts

    if options is not None:
        opts = trace_options_to_at_fitting_opts(options)
    else:
        opts = at_fitting_opts_new()
 
    cdef at_spline_list_array_type *at_spline_list_array = at_splines_new(bitmap, opts, NULL, NULL)
    vector_image = at_splines_to_vector_image(at_spline_list_array)

    at_bitmap_free(bitmap)
    at_fitting_opts_free(opts)
    at_splines_free(at_spline_list_array)

    return vector_image


# Save a Vector object to a file.
def save(vector_image, filename, format = None):
    filename_bytes = filename.encode("utf-8")
    cdef at_spline_writer *writer = NULL

    if format is None:
        writer = at_output_get_handler(filename_bytes)
        if writer is NULL:
            raise ValueError(f"could not find output format for filename '{filename}'")
    else:
        writer = at_output_get_handler_by_suffix(format.encode("utf-8"))
        if writer is NULL:
            raise ValueError(f"unknown output format '{format}'")

    cdef FILE *fd = libc.stdio.fopen(filename_bytes, "wb")
    if fd is NULL:
        raise IOError(f"could not open file '{filename}' for writing")

    cdef at_spline_list_array_type *at_spline_list_array = vector_image_to_at_splines(vector_image)

    at_splines_write(writer, fd, filename_bytes, NULL, at_spline_list_array, NULL, NULL)

    libc.stdio.fclose(fd)
    at_splines_free(at_spline_list_array)


def evaluate_spline_at_points(spline, points):
    n_points = points.shape[0]
    cdef at_spline_type *at_spline = <at_spline_type *>alloc(sizeof(at_spline_type))
    for i in range(4):
        at_spline.v[i].x = spline.points[i].x
        at_spline.v[i].y = spline.points[i].y
        at_spline.v[i].z = spline.points[i].z
    at_spline.degree = spline.degree
    at_spline.linearity = spline.linearity
    cdef float[:,:] new_arr = cvarray(shape=(n_points, 2), itemsize=sizeof(float), format="f") 
    cdef at_real_coord coord
    for i, point in enumerate(points):
        coord = evaluate_spline(at_spline[0], point)
        new_arr[i][0] = coord.x
        new_arr[i][1] = coord.y
    libc.stdlib.free(at_spline)
    return np.asarray(new_arr)

# Initialize AutoTrace.
autotrace_init()
