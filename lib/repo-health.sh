#!/usr/bin/env bash
## Optional upstream repository health warnings.
## API/network/rate-limit failures never fail provisioning. Callers may use
## --quit only when they deliberately want archived/missing/stale repositories
## to be fatal.

_repo_health_fetch() {
	local raw
	raw=$(curl --silent --show-error --location \
		--write-out $'\n%{http_code}' "$1") || return 1
	_repo_health_code=${raw##*$'\n'}
	_repo_health_body=${raw%$'\n'*}
}

repo_health() {
	# Modules execute independently, so this helper provides its own tools rather
	# than relying on an earlier package module.
	pkg_is_installed curl || pkg_install curl
	pkg_is_installed jq || pkg_install jq

	local spec=${1:?repo_health requires a repository}
	shift
	local months=0 quit=false
	while (($#)); do
		case $1 in
		-m)
			months=${2:?repo_health -m requires months}
			shift 2
			;;
		--quit)
			quit=true
			shift
			;;
		*)
			printf 'repo_health: unknown option: %s\n' "$1" >&2
			return 2
			;;
		esac
	done

	local host path project_url activity archived
	case $spec in
	github:*)
		host=github
		path=${spec#github:}
		;;
	gitlab:*)
		host=gitlab
		path=${spec#gitlab:}
		;;
	https://github.com/*)
		host=github
		path=${spec#https://github.com/}
		;;
	https://gitlab.com/*)
		host=gitlab
		path=${spec#https://gitlab.com/}
		;;
	*)
		printf 'repo_health: unsupported repository: %s\n' "$spec" >&2
		return 2
		;;
	esac
	path=${path%.git}
	path=${path%/}
	case $host in
	github) project_url="https://api.github.com/repos/$path" ;;
	gitlab) project_url="https://gitlab.com/api/v4/projects/${path//\//%2F}" ;;
	esac

	local _repo_health_body _repo_health_code
	if ! _repo_health_fetch "$project_url"; then
		printf 'warning: could not query %s repository %s\n' "$host" "$path" >&2
		return 0
	fi
	case $_repo_health_code in
	200) ;;
	404)
		printf 'warning: repository not found: %s\n' "$spec" >&2
		[[ $quit == false ]]
		return
		;;
	*)
		printf 'warning: %s returned HTTP %s for %s\n' \
			"$host" "$_repo_health_code" "$path" >&2
		return 0
		;;
	esac

	archived=$(jq -r '.archived // false' <<<"$_repo_health_body" 2>/dev/null || printf false)
	if [[ $archived == true ]]; then
		printf 'warning: repository is archived: %s\n' "$spec" >&2
		[[ $quit == false ]] || return 1
	fi

	((months > 0)) || return 0
	case $host in
	github)
		activity=$(jq -r '.pushed_at // empty' <<<"$_repo_health_body" 2>/dev/null || true)
		;;
	gitlab)
		activity=
		if _repo_health_fetch "$project_url/repository/commits?per_page=1" &&
			[[ $_repo_health_code == 200 ]]; then
			activity=$(jq -r '.[0].committed_date // empty' \
				<<<"$_repo_health_body" 2>/dev/null || true)
		fi
		;;
	esac
	[[ -n $activity ]] || return 0

	local last_timestamp now_timestamp age_months
	last_timestamp=$(date --date="$activity" +%s 2>/dev/null) || return 0
	now_timestamp=$(date +%s)
	age_months=$(((now_timestamp - last_timestamp) / 2629800))
	if ((age_months > months)); then
		printf 'warning: %s has no code activity for %s months\n' \
			"$spec" "$age_months" >&2
		[[ $quit == false ]] || return 1
	fi
}
