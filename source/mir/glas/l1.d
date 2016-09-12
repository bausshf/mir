/++
$(H2 Level 1)

$(SCRIPT inhibitQuickIndex = 1;)

This is a submodule of $(LINK2 mir_glas.html, mir.glas).

The Level 1 BLAS perform scalar, vector and vector-vector operations.

$(BOOKTABLE $(H2 Matrix-matrix operations),

$(TR $(TH Function Name) $(TH Description))
$(T2 dot, dot product)
$(T2 nrm2, Euclidean norm)
$(T2 sqnrm2, square of Euclidean norm)
$(T2 asum, sum of absolute values)
$(T2 iamax, index of max abs value)
)

License: $(LINK2 http://boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Ilya Yaroshenko

Macros:
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
SUBMODULE = $(LINK2 mir_glas_$1.html, mir.glas.$1)
SUBREF = $(LINK2 mir_glas_$1.html#.$2, $(TT $2))$(NBSP)
+/
module mir.glas.l1;

import std.traits;
import std.meta;
import std.complex : Complex, conj;
import std.typecons: Flag, Yes, No;

import mir.internal.math;
import mir.internal.utility;
import mir.ndslice.internal : fastmath;
import mir.ndslice.slice;
import mir.ndslice.algorithm : ndReduce;

@fastmath realType!T _fabs(T)(in T x)
{
    static if (isComplex!T)
    {
        return x.re.fabs + x.im.fabs;
    }
    else
    static if (isFloatingPoint!T)
    {
        return x.fabs;
    }
    else
    {
        static if (isUnsigned!T)
            return x;
        else
            return (x >= 0 ? x : -x);
    }
}

@fastmath A _fmuladd(A, B, C)(A a, B b, C c)
{
    return a + b * c;
}

@fastmath A _fmuladdc(A, B, C)(A a, B b, C c)
{
    static if (isComplex!B)
    {
        return a + conj(b) * c;
    }
    else
        return a + b * c;
}

@fastmath A _nrm2(A, B)(A a, B b)
{
    static if (isComplex!B)
        return a + b.re * b.re + b.im * b.im;
    else
        return a + b * b;
}

@fastmath A _asum(A, B)(A a, B b)
{
    return a + _fabs(b);
}

private enum _shouldBeCastedToUnqual(T) = (isPointer!T || isDynamicArray!T) && !is(Unqual!T == T);

/++
Forms the dot product of two vectors.
Uses unrolled loops for stride equal to one when compiled with LDC.
Returns: dot product `conj(xᐪ) × y`
Params:
    F = type for summation (optional template parameter)
    x = first n-dimensional tensor
    y = second n-dimensional tensor
BLAS: SDOT, DDOT, SDSDOT, DSDOT, CDOTC, ZDOTC
+/
F dot(F, size_t N, R1, R2)(Slice!(N, R1) x, Slice!(N, R2) y)
{
    static if (allSatisfy!(_shouldBeCastedToUnqual, R1, R2))
    {
        return .dot!F(cast(Slice!(N, Unqual!R1))x, cast(Slice!(N, Unqual!R2))y);
    }
    else
    {
        assert(x.shape == y.shape, "constraints: x and y must have equal shapes");
        pragma(inline, false);
        return ndReduce!(_fmuladdc, Yes.vectorized)(F(0), x, y);
    }
}

/// ditto
auto dot(size_t N, R1, R2)(Slice!(N, R1) x, Slice!(N, R2) y)
{
    return .dot!(Unqual!(typeof(x[0] * y[0])))(x, y);
}

/// SDOT, DDOT
unittest
{
    auto x = slice!double(4);
    auto y = slice!double(4);
    x[] = [0, 1, 2, 3];
    y[] = [4, 5, 6, 7];
    assert(dot(x, y) == 5 + 12 + 21);
}

/// SDSDOT, DSDOT
unittest
{
    auto x = slice!float(4);
    auto y = slice!float(4);
    x[] = [0, 1, 2, 3];
    y[] = [4, 5, 6, 7];
    assert(dot!real(x, y) == 5 + 12 + 21); // 80-bit FP for x86 CPUs
}

/// CDOTC, ZDOTC
unittest
{
    import std.complex;
    alias cd = Complex!double;

    auto x = slice!cd(2);
    auto y = slice!cd(2);
    x[] = [cd(0, 1), cd(2, 3)];
    y[] = [cd(4, 5), cd(6, 7)];
    assert(dot(x, y) == cd(0, -1) * cd(4, 5) + cd(2, -3) * cd(6, 7));
}


/++
Returns the euclidean norm of a vector.
Returns: euclidean norm `sqrt(conj(xᐪ)  × x)`
Params:
    F = type for summation (optional template parameter)
    x = n-dimensional tensor
BLAS: SNRM2, DNRM2, SCNRM2, DZNRM2
+/
F nrm2(F, size_t N, R)(Slice!(N, R) x)
{
    static if (_shouldBeCastedToUnqual!R)
        return .sqnrm2!F(cast(Slice!(N, Unqual!R))x).sqrt;
    else
        return .sqnrm2!F(x).sqrt;
}

/// ditto
auto nrm2(size_t N, R)(Slice!(N, R) x)
{
    return .nrm2!(realType!(typeof(x[0] * x[0])))(x);
}

/// SNRM2, DNRM2
unittest
{
    import mir.internal.math: sqrt;
    auto x = slice!double(4);
    x[] = [0, 1, 2, 3];
    assert(nrm2(x) == sqrt(1.0 + 4 + 9));
}

/// SCNRM2, DZNRM2
unittest
{
    import std.complex;
    alias cd = Complex!double;
    import mir.internal.math: sqrt;

    auto x = slice!cd(2);
    x[] = [cd(0, 1), cd(2, 3)];

    assert(nrm2(x) == sqrt(1.0 + 4 + 9));
}

/++
Forms the square of the euclidean norm.
Uses unrolled loops for stride equal to one when compiled with LDC.
Returns: dot product `conj(xᐪ) × y`
Params:
    F = type for summation (optional template parameter)
    x = n-dimensional tensor
+/
F sqnrm2(F, size_t N, R)(Slice!(N, R) x)
{
    static if (_shouldBeCastedToUnqual!R)
    {
        return .sqnrm2!F(cast(Slice!(N, Unqual!R))x);
    }
    else
    {
        pragma(inline, false);
        return ndReduce!(_nrm2, Yes.vectorized)(F(0), x);
    }
}

/// ditto
auto sqnrm2(size_t N, R)(Slice!(N, R) x)
{
    return .sqnrm2!(realType!(typeof(x[0] * x[0])))(x);
}

///
unittest
{
    auto x = slice!double(4);
    x[] = [0, 1, 2, 3];
    assert(sqnrm2(x) == 1.0 + 4 + 9);
}

///
unittest
{
    import std.complex;
    alias cd = Complex!double;

    auto x = slice!cd(2);
    x[] = [cd(0, 1), cd(2, 3)];

    assert(sqnrm2(x) == 1.0 + 4 + 9);
}

/++
Takes the sum of the `|Re(.)| + |Im(.)|`'s of a vector and
    returns a single precision result.
Returns: sum of the `|Re(.)| + |Im(.)|`'s
Params:
    F = type for summation (optional template parameter)
    x = n-dimensional tensor
BLAS: SASUM, DASUM, SCASUM, DZASUM
+/
F asum(F, size_t N, R)(Slice!(N, R) x)
{
    static if (_shouldBeCastedToUnqual!R)
    {
        return .asum!F(cast(Slice!(N, Unqual!R))x);
    }
    else
    {
        pragma(inline, false);
        return ndReduce!(_asum, Yes.vectorized)(F(0), x);
    }
}

/// ditto
auto asum(size_t N, R)(Slice!(N, R) x)
{
    alias T = typeof(x[0]);
    return .asum!(realType!T)(x);
}

/// SASUM, DASUM
unittest
{
    auto x = slice!double(4);
    x[] = [0, -1, -2, 3];
    assert(asum(x) == 1 + 2 + 3);
}

/// SCASUM, DZASUM
unittest
{
    import std.complex;
    alias cd = Complex!double;

    auto x = slice!cd(2);
    x[] = [cd(0, -1), cd(-2, 3)];

    assert(asum(x) == 1 + 2 + 3);
}

/++
Finds the index of the first element having maximum `|Re(.)| + |Im(.)|`.
Return: index of the first element having maximum `|Re(.)| + |Im(.)|`
Params: x = 1-dimensional tensor
BLAS: ISAMAX, IDAMAX, ICAMAX, IZAMAX
+/
sizediff_t iamax(R)(Slice!(1, R) x)
{
    static if (_shouldBeCastedToUnqual!R)
    {
        return .iamax(cast(Slice!(1, Unqual!R))x);
    }
    else
    {
        pragma(inline, false);
        if (x.length == 0)
            return -1;
        if (x.stride == 0)
            return 0;
        alias T = Unqual!(typeof(x[0]));
        alias F = realType!T;
        static if (isFloatingPoint!F)
            auto m = -double.infinity;
        else
            auto m = F.min;
        sizediff_t l = x.length;
        sizediff_t r = x.length;
        do
        {
            auto e = x.front._fabs;
            if (e > m)
            {
                m = e;
                r = x.length;
            }
            x.popFront;
        }
        while (x.length);
        return l - r;
    }
}

/// ISAMAX, IDAMAX
unittest
{
    auto x = slice!double(6);
    //     0  1   2   3   4  5
    x[] = [0, -1, -2, -3, 3, 2];
    assert(iamax(x) == 3);
    // -1 for empty vectors
    assert(iamax(x[0 .. 0]) == -1);
}

/// ICAMAX, IZAMAX
unittest
{
    import std.complex;
    alias cd = Complex!double;

    auto x = slice!cd(4);
    //        0          1          2         3
    x[] = [cd(0, -1), cd(-2, 3), cd(2, 3), cd(2, 2)];

    assert(iamax(x) == 1);
    // -1 for empty vectors
    assert(iamax(x[$ .. $]) == -1);
}
