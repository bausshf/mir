/++
License:   $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).
Copyright: Copyright © 2016-, Ilya Yaroshenko
Authors:   Ilya Yaroshenko
+/
module mir.sparse.blas.gemm;

import std.traits;
import mir.ndslice.slice;
import mir.ndslice.iterator;
import mir.ndslice.allocation: slice;
import mir.sparse;

/++
General matrix-matrix multiplication.

Params:
    alpha = scalar
    a = sparse matrix (CSR format)
    b = dense matrix
    beta = scalar
    c = dense matrix
Returns:
    `c = alpha * a × b + beta * c` if beta does not equal null and `c = alpha * a × b` otherwise.
+/
void gemm(
    CR,
    CL,
    SliceKind kind1, T1, I1, J1, SliceKind kind2, Iterator2, SliceKind kind3, Iterator3)
(
    in CR alpha,
    Slice!(kind1, [1], FieldIterator!(CompressedField!(T1, I1, J1))) a,
    Slice!(kind2, [2], Iterator2) b,
    in CL beta,
    Slice!(kind3, [2], Iterator3)  c)
in
{
    assert(a.length!0 == c.length!0);
    assert(b.length!1 == c.length!1);
}
body
{
    import mir.ndslice.topology: universal;
    import mir.ndslice.dynamic: transposed;
    auto ct = c.universal.transposed;
    foreach (x; b.universal.transposed)
    {
        import mir.sparse.blas.gemv: gemv;
        gemv(alpha, a, x, beta, ct.front);
        ct.popFront;
    }
}

///
unittest
{
    auto sp = sparse!int(3, 5);
    sp[] =
        [[-5, 1, 7, 7, -4],
         [-1, -5, 6, 3, -3],
         [-5, -2, -3, 6, 0]];

    auto a = sp.compress;

    auto b = slice!double(5, 4);
    b[] =
        [[-5.0, -3, 3, 1],
         [4.0, 3, 6, 4],
         [-4.0, -2, -2, 2],
         [-1.0, 9, 4, 8],
         [9.0, 8, 3, -2]];

    auto c = slice!double(3, 4);

    gemm(1.0, a, b, 0, c);

    assert(c ==
        [[-42.0, 35, -7, 77],
         [-69.0, -21, -42, 21],
         [23.0, 69, 3, 29]]);
}


/++
General matrix-matrix multiplication with transformation.

Params:
    alpha = scalar
    a = sparse matrix (CSR format)
    b = dense matrix
    beta = scalar
    c = dense matrix
Returns:
    `c = alpha * aᵀ × b + beta * c` if beta does not equal null and `c = alpha * aᵀ × b` otherwise.
+/
void gemtm(
    CR,
    CL,
    SliceKind kind1, T1, I1, J1, SliceKind kind2, Iterator2, SliceKind kind3, Iterator3)
(
    in CR alpha,
    Slice!(kind1, [1], FieldIterator!(CompressedField!(T1, I1, J1))) a,
    Slice!(kind2, [2], Iterator2) b,
    in CL beta,
    Slice!(kind3, [2], Iterator3)  c)
in
{
    assert(a.length!0 == b.length!0);
    assert(b.length!1 == c.length!1);
}
body
{
    import mir.ndslice.topology: universal;
    import mir.ndslice.dynamic: transposed;
    auto ct = c.universal.transposed;
    foreach (x; b.universal.transposed)
    {
        import mir.sparse.blas.gemv: gemtv;
        gemtv(alpha, a, x, beta, ct.front);
        ct.popFront;
    }
}


///
unittest
{
    auto sp = sparse!int(5, 3);
    sp[] =
        [[-5, -1, -5],
         [1, -5, -2],
         [7, 6, -3],
         [7, 3, 6],
         [-4, -3, 0]];

    auto a = sp.compress;

    auto b = slice!double(5, 4);
    b[] =
        [[-5.0, -3, 3, 1],
         [4.0, 3, 6, 4],
         [-4.0, -2, -2, 2],
         [-1.0, 9, 4, 8],
         [9.0, 8, 3, -2]];

    auto c = slice!double(3, 4);

    gemtm(1.0, a, b, 0, c);

    assert(c ==
        [[-42.0, 35, -7, 77],
         [-69.0, -21, -42, 21],
         [23.0, 69, 3, 29]]);
}

/++
Selective general matrix multiplication with selector sparse matrix.
Params:
    a = dense matrix
    b = dense matrix
    c = sparse matrix (CSR format)
Returns:
    `c[available indexes] <op>= (a × b)[available indexes]`.
+/
void selectiveGemm(string op = "", SliceKind kind1, SliceKind kind2, SliceKind kind3, T, T3, I3, J3)
(Slice!(kind1, [2], T*) a, Slice!(kind2, [2], T*) b, Slice!(kind3, [1], FieldIterator!(CompressedField!(T3, I3, J3))) c)
in
{
    assert(a.length!1 == b.length!0);
    assert(c.length!0 == a.length!0);
    foreach (r; c)
        if (r.indexes.length)
            assert(r.indexes[$-1] < b.length!1);
}
body
{
    import mir.ndslice.topology: universal;
    import mir.ndslice.dynamic: transposed;
    import mir.sparse.blas.gemv: selectiveGemv;

    auto bt = b.universal.transposed;
    foreach (r; c)
    {
        selectiveGemv!op(bt, a.front, r);
        a.popFront;
    }
}

///
unittest
{
    auto a = slice!double(3, 5);
    a[] =
        [[-5, 1, 7, 7, -4],
         [-1, -5, 6, 3, -3],
         [-5, -2, -3, 6, 0]];

    auto b = slice!double(5, 4);
    b[] =
        [[-5.0, -3, 3, 1],
         [4.0, 3, 6, 4],
         [-4.0, -2, -2, 2],
         [-1.0, 9, 4, 8],
         [9.0, 8, 3, -2]];

    // a * b ==
    //    [[-42.0, 35, -7, 77],
    //     [-69.0, -21, -42, 21],
    //     [23.0, 69, 3, 29]]);

    auto cs = sparse!double(3, 4);
    cs[0, 2] = 1;
    cs[0, 1] = 3;
    cs[2, 3] = 2;

    auto c = cs.compress;

    selectiveGemm!"*"(a, b, c);
    assert(c.length == 3);
    assert(c[0].indexes == [1, 2]);
    assert(c[0].values == [105, -7]);
    assert(c[1].indexes == []);
    assert(c[1].values == []);
    assert(c[2].indexes == [3]);
    assert(c[2].values == [58]);
}
