#!/usr/bin/env bash

# Strip JSONC comments without corrupting comment-like text inside strings.
json_strip_comments() {
	awk '
	BEGIN { state = 0 }
	{
		line = $0; n = length(line); i = 1; out = ""
		while (i <= n) {
			if (state == 2) {
				idx = index(substr(line, i), "*/")
				if (idx > 0) { state = 0; i += idx + 1 } else { i = n + 1 }
				continue
			}
			if (state == 1) {
				c = substr(line, i, 1)
				if (c == "\\" && i < n) { out = out c substr(line, i + 1, 1); i += 2; continue }
				if (c == "\"") state = 0
				out = out c; i++; continue
			}
			c = substr(line, i, 1); c2 = substr(line, i, 2)
			if (c == "\"") { state = 1; out = out c; i++; continue }
			if (c2 == "//") { i = n + 1; continue }
			if (c2 == "/*") { state = 2; i += 2; continue }
			out = out c; i++
		}
		print out
	}' "$@"
}
