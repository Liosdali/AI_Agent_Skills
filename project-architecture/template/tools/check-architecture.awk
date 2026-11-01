# Reads source files line by line and prints violations as RULE|file|text.
# root: source root, prefix: project import prefix, allowed: allowed top-level folders.

BEGIN {
  count = split("app shell screens business jobs shared platform", names, " ")
  for (i = 1; i <= count; i++) isLayer[names[i]] = 1

  count = split(allowed, names, " ")
  for (i = 1; i <= count; i++) isAllowed[names[i]] = 1

  forbidden["shell"]    = " app screens jobs platform "
  forbidden["screens"]  = " app shell jobs platform "
  forbidden["jobs"]     = " app shell screens platform "
  forbidden["business"] = " app shell screens jobs "
  forbidden["shared"]   = " app shell screens jobs business "
  forbidden["platform"] = " app shell screens jobs business "
}

FNR == 1 {
  file = FILENAME
  relative = substr(file, length(root) + 2)

  extension = file
  sub(/^.*\./, "", extension)

  sourceLayer = relative
  sub(/\/.*$/, "", sourceLayer)
  if (relative ~ /\// && !(sourceLayer in isAllowed)) report("FOLDER", "")

  fileName = tolower(file)
  sub(/^.*\//, "", fileName)
  if (fileName ~ /(manager|helper|utils?)\.[a-z]+$/) report("FILE_NAME", "")
}

{
  line = $0
  sub(/\r$/, "", line)
  if (FNR == 1) sub(/^\357\273\277/, "", line)  # UTF-8 BOM

  if (line ~ /(AppFrame|AppLayout|AppShell|HomeShell)\.(getInstance|instance)/) {
    report("STATIC_SHELL", line)
  }

  target = importTarget(line)
  if (target == "") next

  path = resolveImport(target)
  if (path == "") next

  targetLayer = path
  sub(/\/.*$/, "", targetLayer)
  if (!(targetLayer in isLayer)) next

  if (isForbidden(sourceLayer, targetLayer, path)) report("DEPENDENCY", line)
  if (targetLayer == "business" && relative ~ /\/sections\// && isDataAccess(path)) {
    report("SECTION_DATA", line)
  }
}

function isForbidden(source, target, fullPath) {
  if (!(source in forbidden)) return 0
  if (index(forbidden[source], " " target " ") == 0) return 0
  if (target == "platform" && fullPath ~ /^platform\/(logging|config)(\/|$)/) return 0
  return 1
}

function isDataAccess(fullPath,    name) {
  name = tolower(fullPath)
  sub(/^.*\//, "", name)
  sub(/\.[a-z]+$/, "", name)
  return name ~ /(store|service)$/
}

# Returns the target of an import line, or empty if it is not an import line.
function importTarget(text,    value) {
  if (extension ~ /^(java|kt|py)$/) {
    if (text !~ /^[ \t]*(import|from)[ \t]/) return ""
    value = text
    sub(/^[ \t]*(import|from)[ \t]+/, "", value)
    sub(/^static[ \t]+/, "", value)
    sub(/[ \t;,].*$/, "", value)
    return value
  }

  if (text ~ /^[ \t]*import[ \t(]/ || text ~ /^[ \t]*[}]?[ \t]*from[ \t]*["']/ ||
      text ~ /^[ \t]*export[ \t].*from[ \t]*["']/ || text ~ /^[ \t]*export[ \t]+["']/ ||
      text ~ /require\(/) {
    if (match(text, /["'][^"']+["']/)) return substr(text, RSTART + 1, RLENGTH - 2)
  }
  return ""
}

# Turns the target into a path relative to the source root, or empty if outside the project.
function resolveImport(value,    dots, rest, i, path) {
  if (extension == "py" && substr(value, 1, 1) == ".") {
    match(value, /^\.+/)
    dots = RLENGTH
    rest = substr(value, dots + 1)
    gsub(/\./, "/", rest)
    path = ""
    for (i = 1; i < dots; i++) path = path "../"
    return resolveRelative(path rest)
  }

  if (extension ~ /^(js|jsx|ts|tsx|dart)$/ && substr(value, 1, 1) == ".") {
    return resolveRelative(value)
  }
  if (extension == "dart" && value !~ /:/) return resolveRelative(value)

  if (prefix != "" && (index(value, prefix ".") == 1 || index(value, prefix "/") == 1)) {
    rest = substr(value, length(prefix) + 2)
    if (rest !~ /\//) gsub(/\./, "/", rest)
    return rest
  }
  return ""
}

function resolveRelative(value,    stack, parts, depth, count, i, path) {
  depth = split(relative, stack, "/") - 1
  count = split(value, parts, "/")
  for (i = 1; i <= count; i++) {
    if (parts[i] == "" || parts[i] == ".") continue
    if (parts[i] == "..") {
      if (depth == 0) return ""
      depth--
      continue
    }
    stack[++depth] = parts[i]
  }

  path = ""
  for (i = 1; i <= depth; i++) path = path (i > 1 ? "/" : "") stack[i]
  return path
}

function report(rule, text) {
  sub(/^[ \t]+/, "", text)
  sub(/[ \t]+$/, "", text)
  print rule "|" file "|" text
}
