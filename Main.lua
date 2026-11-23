local Format, Concat, Insert, Find = string.format, table.concat, table.insert, table.find
-- Api
local ClassMap, Properties, Defaults = {}, {}, {}
local Json = isfile and isfile("robloxproperties.json") and readfile("robloxproperties.json")
--
local Identifiers, Used = {}, {}

if not Json then
    Json = game:HttpGet("https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/refs/heads/roblox/Mini-API-Dump.json")
    pcall(writefile, "robloxproperties.json", Json)
end

for _, Class in next, game:GetService("HttpService"):JSONDecode(Json).Classes do
    ClassMap[Class.Name] = Class
end

local function Get(Object, Property)
    return Object[Property]
end

local function GetDefault(ClassName)
    if Defaults[ClassName] == nil then
        local Success, Object = pcall(Instance.new, ClassName)
        Defaults[ClassName] = Success and Object
    end

    return Defaults[ClassName]
end

local function GetProperties(ClassName)
    local List = Properties[ClassName]
    local Class = ClassMap[ClassName]
    local Seen = {}

    if List then
        return List
    end

    List = {}

    while Class do
        for _, Member in next, Class.Members or {} do
            local Tags = Member.Tags or {}

            if
                Member.MemberType == "Property"
                and not Seen[Member.Name]
                and Member.Name ~= "Name"
                and Member.Name ~= "Parent"
                and not Find(Tags, "ReadOnly")   --if blah blah blah lol xd
                and not Find(Tags, "Deprecated")
                and not Find(Tags, "Hidden")
                and not Find(Tags, "NotScriptable")
            then
                Seen[Member.Name] = true
                Insert(List, Member.Name)
            end
        end

        Class = ClassMap[Class.Superclass]
    end

    Properties[ClassName] = List

    return List
end

local function GetIdentifier(Object)
    local Identifier = Object.Name
    local Count = 1

    while Used[Identifier] do
        Count += 1
        Identifier = Object.Name .. " " .. Count
    end

    Used[Identifier] = true
    Identifiers[Object] = Identifier

    return Identifier
end

-- Formatting
local FormatValue

local function FormatString(Value)
    return '"' .. (tostring(Value)
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
        :gsub("%c", function(Character)
            return Format("\\%03d", Character:byte())
        end)) .. '"'
end

local function FormatNumber(Number)
    if Number ~= Number then
        return "0/0"
    elseif Number == math.huge then
        return "math.huge"
    elseif Number == -math.huge then
        return "-math.huge"
    end

    for Precision = 1, 17 do
        local Result = Format("%." .. Precision .. "g", Number)

        if tonumber(Result) == Number then
            return Result
        end
    end

    return Format("%.17g", Number)
end

local function FormatReference(Identifier)
    return Format("Instances[%s]", FormatString(Identifier))
end

local function FormatInstance(Value)
    local Path, Current = {}, Value
    local Root, Result

    if Identifiers[Value] then
        return FormatReference(Identifiers[Value])
    elseif Value == game then
        return "game"
    elseif Value == workspace then
        return "workspace"
    elseif Value == game:GetService("Players").LocalPlayer then
        return 'game:GetService("Players").LocalPlayer'
    end

    while Current and Current ~= game do
        Insert(Path, 1, Current)
        Current = Current.Parent
    end

    if Current ~= game then
        return "nil"
    end

    Root = Path[1]

    Result =
        pcall(game.GetService, game, Root.ClassName)
        and Format("game:GetService(%s)", FormatString(Root.ClassName))
        or Format("game:FindFirstChild(%s)", FormatString(Root.Name))

    for Index = 2, #Path do
        Result ..= Format(":FindFirstChild(%s)", FormatString(Path[Index].Name))
    end

    return (Result:gsub('^game:GetService%("Workspace"%)', "workspace"))
end

local Formatters = {
    ["nil"] = function()
        return "nil"
    end,
    --
    boolean = tostring,
    number = FormatNumber,
    string = FormatString,
    Instance = FormatInstance,
    EnumItem = tostring,
    Enum = tostring,
    --
    Vector2 = function(Value)
        return Format("Vector2.new(%s, %s)", FormatNumber(Value.X), FormatNumber(Value.Y))
    end,

    Vector2int16 = function(Value)
        return Format("Vector2int16.new(%d, %d)", Value.X, Value.Y)
    end,

    Vector3 = function(Value)
        return Format("Vector3.new(%s, %s, %s)", FormatNumber(Value.X), FormatNumber(Value.Y), FormatNumber(Value.Z))
    end,

    Vector3int16 = function(Value)
        return Format("Vector3int16.new(%d, %d, %d)", Value.X, Value.Y, Value.Z)
    end,

    UDim = function(Value)
        return Format("UDim.new(%s, %d)", FormatNumber(Value.Scale), Value.Offset)
    end,

    UDim2 = function(Value)
        return Format(
            "UDim2.new(%s, %d, %s, %d)",
            FormatNumber(Value.X.Scale),
            Value.X.Offset,
            FormatNumber(Value.Y.Scale),
            Value.Y.Offset
        )
    end,

    Color3 = function(Value)
        return Format(
            "Color3.fromRGB(%d, %d, %d)",
            math.floor(Value.R * 255 + 0.5),
            math.floor(Value.G * 255 + 0.5),
            math.floor(Value.B * 255 + 0.5)
        )
    end,

    BrickColor = function(Value)
        return Format("BrickColor.new(%d)", Value.Number)
    end,

    CFrame = function(Value)
        local Parts = {}

        for Index, Component in next, {Value:GetComponents()} do
            Parts[Index] = FormatNumber(Component)
        end

        return "CFrame.new(" .. Concat(Parts, ", ") .. ")"
    end,

    NumberRange = function(Value)
        return Format("NumberRange.new(%s, %s)", FormatNumber(Value.Min), FormatNumber(Value.Max))
    end,

    NumberSequence = function(Value)
        local Parts = {}

        for Index, Keypoint in next, Value.Keypoints do
            Parts[Index] = Format(
                "NumberSequenceKeypoint.new(%s, %s, %s)",
                FormatNumber(Keypoint.Time),
                FormatNumber(Keypoint.Value),
                FormatNumber(Keypoint.Envelope)
            )
        end

        return "NumberSequence.new({" .. Concat(Parts, ", ") .. "})"
    end,

    ColorSequence = function(Value)
        local Parts = {}

        for Index, Keypoint in next, Value.Keypoints do
            Parts[Index] = Format(
                "ColorSequenceKeypoint.new(%s, %s)",
                FormatNumber(Keypoint.Time),
                FormatValue(Keypoint.Value)
            )
        end

        return "ColorSequence.new({" .. Concat(Parts, ", ") .. "})"
    end,

    Rect = function(Value)
        return Format(
            "Rect.new(%s, %s, %s, %s)",
            FormatNumber(Value.Min.X),
            FormatNumber(Value.Min.Y),
            FormatNumber(Value.Max.X),
            FormatNumber(Value.Max.Y)
        )
    end,

    Ray = function(Value)
        return Format("Ray.new(%s, %s)", FormatValue(Value.Origin), FormatValue(Value.Direction))
    end,

    PhysicalProperties = function(Value)
        return Format(
            "PhysicalProperties.new(%s, %s, %s, %s, %s)",
            FormatNumber(Value.Density),
            FormatNumber(Value.Friction),
            FormatNumber(Value.Elasticity),
            FormatNumber(Value.FrictionWeight),
            FormatNumber(Value.ElasticityWeight)
        )
    end,

    Font = function(Value)
        return Format(
            "Font.new(%s, %s, %s)",
            FormatValue(Value.Family),
            FormatValue(Value.Weight),
            FormatValue(Value.Style)
        )
    end,

    Content = function(Value)
        return Value.Uri and Format("Content.fromUri(%s)", FormatString(Value.Uri)) or "Content.none"
    end,

    DateTime = function(Value)
        return Format("DateTime.fromUnixTimestampMillis(%d)", Value.UnixTimestampMillis)
    end,
}

-- Returns nil for types that cannot be written out, so the property is skipped
function FormatValue(Value)
    local Formatter = Formatters[typeof(Value)]

    return Formatter and Formatter(Value)
end

-- Main
local function Instance2Luau(Root, Delayed)
    local Start = tick()
    local Instances = Root:GetDescendants()
    local Declarations, Lines = {}, {}

    Identifiers, Used = {}, {}
    Insert(Instances, 1, Root)

    -- The first pass creates every instance so that properties can be safely reference each other
    for _, Object in next, Instances do
        if Delayed then
            task.wait()
        end

        if GetDefault(Object.ClassName) then
            Insert(Declarations, Format(
                "\t[%s] = Instance.new(%s),",
                FormatString(GetIdentifier(Object)),
                FormatString(Object.ClassName)
            ))
        end
    end

    for _, Object in next, Instances do
        local Identifier = Identifiers[Object]

        if Delayed then
            task.wait()
        end

        if Identifier then
            local Default = GetDefault(Object.ClassName)
            local Reference = FormatReference(Identifier)

            for _, Property in next, GetProperties(Object.ClassName) do
                local Success, Value = pcall(Get, Object, Property)
                local DefaultSuccess, DefaultValue = pcall(Get, Default, Property)

                if Success and not (DefaultSuccess and Value == DefaultValue) then
                    local FormatSuccess, Formatted = pcall(FormatValue, Value)

                    if FormatSuccess and Formatted then
                        Insert(Lines, Format("Set(%s, %s, %s)", Reference, FormatString(Property), Formatted))
                    end
                end
            end

            Insert(Lines, Format("Set(%s, \"Name\", %s)", Reference, FormatString(Object.Name)))

            if Object == Root then
                Insert(Lines, Format("Set(%s, \"Parent\", %s)", Reference, FormatValue(Object.Parent)))
            elseif Identifiers[Object.Parent] then
                Insert(Lines, Format("Set(%s, \"Parent\", %s)", Reference, FormatReference(Identifiers[Object.Parent])))
            end

            Insert(Lines, "")
        end
    end

    return "local Instances = {\n" .. Concat(Declarations, "\n") .. "\n}\n\n" .. [[local function Set(Object, Property, Value)
        pcall(function()
            Object[Property] = Value
        end)
    end

    ]] .. Concat(Lines, "\n"), tick() - Start
end

return Instance2Luau
