/**
 * This module contains the implementation for the internal pixel storage
 * mechanisms.
 */
module daffodil.pixel;

import std.conv;
import std.array;
import std.format;
import std.traits;
import std.algorithm;

import daffodil.colorspace;

/**
 * The storage struct for a color.
 */
struct Pixel(V) if (isColorValue!V) {
    /// The type used to store individual values for a color
    alias Value = V;

    /// The values of the color
    Value[] values;

    /// The color space used for operations with the color
    const ColorSpace* colorSpace;

    alias values this;

    ///
    this(Value[] values, const ColorSpace* colorSpace) {
        this.values = values;
        this.colorSpace = colorSpace;
    }

    /// Ditto
    static if (!is(V == real)) {
        this(real[] values, const ColorSpace* colorSpace) {
            this(values.toColorValues!V, colorSpace);
        }
    }

    /// Ditto
    this(size_t size, const ColorSpace* colorSpace) {
        this(new Value[size], colorSpace);
    }

    // TODO: Memory optimisation

    ///
    Pixel!V opBinary(string op : "*")(const real other) const {
        real[] target = new real[this.length];
        colorSpace.opScalarMul(values.toReals, other, target);
        return Pixel!V(target, colorSpace);
    }

    ///
    Pixel!V opBinary(string op : "+")(const Pixel!V other) const {
        // TODO: Check other.colorSpace
        real[] target = new real[this.length];
        colorSpace.opColorAdd(values.toReals, other.values.toReals, target);
        return Pixel!V(target, colorSpace);
    }

    ///
    void opOpAssign(string op : "*")(const real other) {
        colorSpace.opScalarMul(values, other, values);
    }

    ///
    void opOpAssign(string op : "+")(const Pixel!V other) {
        colorSpace.opColorAdd(values, other, values);
    }

    ///
    void opAssign(const Pixel!V other) {
        assert(other.length == this.length);
        foreach (index; 0..this.length) {
            this[index] = other[index];
        }
    }

    /// Clear all the color values to 0
    void clear() {
        foreach (index; 0..this.length) {
            this[index] = 0;
        }
    }

    /// Return a duplicate color in the same color space
    @property auto dup() {
        return Pixel!V(values.dup, colorSpace);
    }
}

/**
 * Template for checking whether a type is a valid color value. Color values are
 * what daffodil stores internally.
 *
 * Any floating point type, unsigned integreal or valid
 * :d:func:`isCustomColorValue` is a valid color value.
 */
template isColorValue(V) {
    enum isColorValue = isFloatingPoint!V ||
                        isIntegral!V && isUnsigned!V ||
                        isCustomColorValue!V;
}

///
@("isColorValue")
unittest {
    assert(isColorValue!ubyte);
    assert(isColorValue!uint);
    assert(isColorValue!ulong);
    assert(!isColorValue!int);
    assert(isColorValue!float);
    assert(isColorValue!real);
}

/**
 * Template for checking whether a type is a valid custom color value. A custom
 * color value must have a static ``init`` property, a static ``fromReal`` that
 * converts a real to ``V``, and a ``toReal`` function that converts a ``V``
 * back to a real.
 */
template isCustomColorValue(V) {
    enum isCustomColorValue = is(typeof(
        (inout int = 0) {
            V v = V.init;
            v = V.fromReal(cast(real)1.0);
            real r = v.toReal();
        }
    ));
}

///
@("isCustomColorValue")
unittest {
    static struct IntCV {
        int value = 0;

        static auto fromReal(real v) {
            return IntCV(cast(int)(v / int.max));
        }

        real toReal() {
            return cast(real)value / int.max;
        }
    }

    assert(isCustomColorValue!IntCV);
    assert(isColorValue!IntCV);
}

/**
 * Converts a real to a specified color value.
 */
V toColorValue(V)(const real value) if (isColorValue!V) {
    static if (isFloatingPoint!V) {
        return value;
    } else static if (isIntegral!V) {
        return cast(V)(V.max * value.clamp(0, 1));
    } else {
        return V.fromReal(value);
    }
}

/**
 * Converts an array of reals to an array of specified color values.
 */
V[] toColorValues(V)(const real[] values) if (isColorValue!V) {
    return values.map!(toColorValue!V).array;
}

/**
 * Converts a valid color value to a real.
 */
real toReal(V)(const V value) if (isColorValue!V) {
    static if (isFloatingPoint!V) {
        return value;
    } else static if (isIntegral!V) {
        return cast(real)value / V.max;
    } else {
        return value.toReal();
    }
}

/**
 * Converts an array of valid color values to an array of reals.
 */
real[] toReals(V)(const V[] values) if (isColorValue!V) {
    return values.map!(toReal!V).array;
}
