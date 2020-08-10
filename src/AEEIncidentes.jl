module AEEIncidentes

using HTTP: request
using JSON3: JSON3, StructType, Struct, Mutable
using LibPQ: Connection, load!, execute
using Dates: DateTime, now, DateFormat, Hour
using TimeZones: ZonedDateTime, utc_tz, UTC
import Base: getproperty
import DataFrames: DataFrame

const AEEDTF = DateFormat("yyyy-mm-ddTHH:MM:SSz")

conn = Connection("dbname = sdad")
latest = execute(conn, "SELECT MAX(statustime) latest FROM aeepr.incidentes;", not_null = true) |>
    (obj -> round(only(getproperty.(obj, :latest)), Hour))
mutable struct Artifact
    id :: UInt64
    created_at :: String
    Artifact() = new()
end
StructType(::Type{Artifact}) = Mutable()
struct Artifacts
    total_count :: UInt16
    artifacts :: Vector{Artifact}
end
StructType(::Type{Artifacts}) = Struct()
function getproperty(obj::Artifact, sym::Symbol)
    if sym == :created_at
        created_at = floor(DateTime(ZonedDateTime(getfield(obj, sym), AEEDTF), UTC), Hour)
    else
        getfield(obj, sym)
    end
end
function list_artifacts(latest::DateTime = now() - Day(92))
    response = request("GET",
                       "https://api.github.com/repos/Nosferican/AEEIncidentes/actions/artifacts?per_page=100",
                       ["Accept" => "application/vnd.github.v3+json",
                        "Time-Zone" => "GMT",
                       ])
    @assert response.status == 200 "GH API is not working"
    json = JSON3.read(response.body, Artifacts)
    artifacts = json.artifacts
    @assert latest ≥ artifacts[end].created_at "Need manual check: older releases need to be added"
    filter(artifact -> artifact.created_at > latest, artifacts)
end
function DataFrame(obj::Artifact)
    # obj = artifacts[51]
    statustime = floor(obj.created_at, Hour)
    filename = string(string(statustime)[1:13], ".jsonl")
    if !isfile(joinpath("data", filename))
        response = request("GET",
                           "https://api.github.com/repos/Nosferican/AEEIncidentes/actions/artifacts/$(obj.id)/zip",
                           ["Accept" => "application/vnd.github.v3+json",
                            "Time-Zone" => "GMT",
                            "User-Agent" => ENV["GH_USR"],
                            "Authorization" => "token $(ENV["GH_PAT_AEE"])",
                           ])
        write(joinpath("data", "$filename.zip"), response.body)
        run(`unzip -q data/$filename.zip -d data`)
        rm(joinpath("data", "$filename.zip"))
    end
    lns = filter!(!isempty, readlines(joinpath("data", filename)))
    if !isempty(lns)
        data = DataFrame(reduce(vcat, JSON3.read(ln) for ln in lns))
        data[!,:statustime] .= statustime
    else
        data = DataFrame([DateTime, String, String], [:statustime, :zone, :area], 0)
    end
    data
end
artifacts = list_artifacts(latest)
if !isempty(artifacts)
    data = sort!(reduce(vcat, DataFrame(artifact) for artifact in artifacts)[!,[:statustime, :area, :zone]])
    execute(conn, "BEGIN;")
    load!(data,
          conn,
          string("INSERT INTO aeepr.incidentes VALUES(",
                 join(("\$$i" for i in 1:size(data, 2)), ','),
                 ") ON CONFLICT ON CONSTRAINT incidentes_pkey DO NOTHING;"))
    execute(conn, "COMMIT;")
    close(conn)
    foreach(file -> rm(joinpath("data", file)), filter!(x -> occursin(r"\d{4}-\d{2}-\d{2}T\d{2}\.json", x), readdir("data")))
end

end # module
