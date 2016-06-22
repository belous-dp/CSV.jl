VERSION >= v"0.4.0-dev+6521" && __precompile__(true)
module CSV

using DataStreams, DataFrames, NullableArrays, WeakRefStrings

export Data

if !isdefined(Core, :String)
    typealias String UTF8String
end

if Base.VERSION < v"0.5.0-dev+4631"
    unsafe_wrap{A<:Array}(::Type{A}, ptr, len) = pointer_to_array(ptr, len)
    unsafe_string(ptr, len) = utf8(ptr, len)
    unsafe_wrap(::Type{String}, ptr, len) = unsafe_string(ptr, len)
    escape_string(io, str1, str2) = print_escaped(io, str1, str2)
end

immutable CSVError <: Exception
    msg::String
end

const RETURN  = UInt8('\r')
const NEWLINE = UInt8('\n')
const COMMA   = UInt8(',')
const QUOTE   = UInt8('"')
const ESCAPE  = UInt8('\\')
const PERIOD  = UInt8('.')
const SPACE   = UInt8(' ')
const TAB     = UInt8('\t')
const MINUS   = UInt8('-')
const PLUS    = UInt8('+')
const NEG_ONE = UInt8('0')-UInt8(1)
const ZERO    = UInt8('0')
const TEN     = UInt8('9')+UInt8(1)
Base.isascii(c::UInt8) = c < 0x80

@inline function unsafe_read(from::Base.AbstractIOBuffer, ::Type{UInt8}=UInt8)
    @inbounds byte = from.data[from.ptr]
    from.ptr = from.ptr + 1
    return byte
end
unsafe_read(from::IO, T) = Base.read(from, T)

@inline function unsafe_peek(from::Base.AbstractIOBuffer)
    @inbounds byte = from.data[from.ptr]
    return byte
end
unsafe_peek(from::IO) = Base.peek(from)

"""
Represents the various configuration settings for csv file parsing.

 * `delim`::Union{Char,UInt8} = how fields in the file are delimited
 * `quotechar`::Union{Char,UInt8} = the character that indicates a quoted field that may contain the `delim` or newlines
 * `escapechar`::Union{Char,UInt8} = the character that escapes a `quotechar` in a quoted field
 * `null`::String = indicates how NULL values are represented in the dataset
 * `dateformat`::Union{AbstractString,Dates.DateFormat} = how dates/datetimes are represented in the dataset
"""
type Options
    delim::UInt8
    quotechar::UInt8
    escapechar::UInt8
    separator::UInt8
    decimal::UInt8
    null::String # how null is represented in the dataset
    nullcheck::Bool   # do we have a custom null value to check for
    dateformat::Dates.DateFormat
    datecheck::Bool   # do we have a custom dateformat to check for
end

Options(;delim=COMMA,quotechar=QUOTE,escapechar=ESCAPE,null=String(""),dateformat=Dates.ISODateFormat) =
    Options(delim%UInt8,quotechar%UInt8,escapechar%UInt8,COMMA,PERIOD,
            null,null != "",isa(dateformat,Dates.DateFormat) ? dateformat : Dates.DateFormat(dateformat),dateformat == Dates.ISODateFormat)
function Base.show(io::IO,op::Options)
    println("    CSV.Options:")
    println(io,"        delim: '",Char(op.delim),"'")
    println(io,"        quotechar: '",Char(op.quotechar),"'")
    print(io,"        escapechar: '"); escape_string(io,string(Char(op.escapechar)),"\\"); println(io,"'")
    print(io,"        null: \""); escape_string(io,op.null,"\\"); println(io,"\"")
    print(io,"        dateformat: ",op.dateformat)
end

"`CSV.Source` satisfies the `DataStreams` interface for data processing for delimited `IO`."
type Source{I<:IO} <: Data.Source
    schema::Data.Schema
    options::Options
    data::I
    datapos::Int # the position in the IOBuffer where the rows of data begins
    fullpath::String
end

function Base.show(io::IO,f::Source)
    println(io,"CSV.Source: ",f.fullpath)
    println(io,f.options)
    showcompact(io, f.schema)
end

type Sink{I<:IO} <: Data.Sink
    schema::Data.Schema
    options::Options
    data::I
    datapos::Int # the byte position in `io` where the data rows start
    quotefields::Bool # whether to always quote string fields or not
end

include("parsefields.jl")
include("io.jl")
include("Source.jl")
include("Sink.jl")

end # module
