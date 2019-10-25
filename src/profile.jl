# Profiler control

export
    @profile, @cuprofile

"""
    @profile ex

Run expressions while activating the CUDA profiler.

Note that this API is used to programmatically control the profiling granularity by allowing
profiling to be done only on selective pieces of code. It does not perform any profiling on
itself, you need external tools for that.
"""
macro profile(ex)
    quote
        Profile.start()
        local ret = $(esc(ex))
        Profile.stop()
        ret
    end
end


module Profile

using ..CUDAdrv

const nsight = Ref{Union{Nothing,String}}(nothing)


"""
    start()

Enables profile collection by the active profiling tool for the current context. If
profiling is already enabled, then this call has no effect.
"""
function start()
    if nsight[] !== nothing
        run(`$(nsight[]) start`)
    else
        @warn("""Calling CUDAdrv.@profile only informs an external profiler to start.
                 The user is responsible for launching Julia under a CUDA profiler like `nvprof`.

                 For improved usability, launch Julia under the Nsight Systems profiler:
                 nsys launch -t cuda,cublas,cudnn,nvtx julia""",
              maxlog=1)
    end
    CUDAdrv.cuProfilerStart()
end

"""
    stop()

Disables profile collection by the active profiling tool for the current context. If
profiling is already disabled, then this call has no effect.
"""
function stop()
    if nsight[] !== nothing
        run(`$(nsight[]) stop`)
        @info "Profiling has finished, open the report listed above with `nsight-sys`"
    else
        CUDAdrv.cuProfilerStop()
    end
end

function __init__()
    # find the active Nsight Systems profiler
    if haskey(ENV, "CUDA_INJECTION64_PATH")
        lib = ENV["CUDA_INJECTION64_PATH"]
        dir = dirname(lib)

        nsight[] = joinpath(dir, "nsys")
        @assert isfile(nsight[])

        @info "Running under Nsight Systems, CUDAdrv.@profile will automatically start the profiler"
    else
        nsight[] = nothing
    end
end

end
