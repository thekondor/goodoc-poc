#!/usr/bin/env bash

if [ -n "${DEBUG}" ]; then
    set -x
fi

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
readonly SELF_DIR

# shellcheck disable=SC1091
source "${SELF_DIR}/deps.sh.inc"

readonly CONFIG_FILEPATH="${PWD}/config.yml"
if [ ! -f "${CONFIG_FILEPATH}" ]; then
    echo "- error: \"${CONFIG_FILEPATH}\" is not existent"
    exit 1
fi

# shellcheck disable=SC1091
source "${SELF_DIR}/config-opts.sh.inc"

ALREADY_UPDATED_REPOS_CACHE="${OPT_REPO_CACHE_DIR}/_repos_and_deps_processed.cache-git"
readonly ALREADY_UPDATED_REPOS_CACHE
if [ -z "${DEV_SKIP_REPSDEPS_UPDATE}" ]; then
    if ! :> "${ALREADY_UPDATED_REPOS_CACHE}"; then
        echo "- error: failed to clean up '${ALREADY_UPDATED_REPOS_CACHE}'"
        exit 1
    fi

    while read -r repo_name; do
        if ! "${SELF_DIR}/gomod-deps-helper.sh" "${OPT_REPO_CACHE_DIR}" "${OPT_GITHUB_ORG_NAME}" "${repo_name}" "${ALREADY_UPDATED_REPOS_CACHE}"; then
            echo "- error: failed to retrieve dependencies for repo=${repo_name}"
            exit 1
        fi
    done < <(yq ".repos[]" < "${CONFIG_FILEPATH}")
else
    echo "+ dev: ${OPT_REPO_CACHE_DIR} initialization skipped"
fi

REPOS_WITH_GENERATED_DOCS="${OPT_REPO_CACHE_DIR}/_repos_and_deps_processed.cache-doc2go"
readonly REPOS_WITH_GENERATED_DOCS
if [ -z "${DEV_SKIP_DOC2GO}" ]; then
    if ! :> "${REPOS_WITH_GENERATED_DOCS}"; then
        echo "- error: failed to clean up '${REPOS_WITH_GENERATED_DOCS}'"
        exit 1
    fi

    while read -r repo_name; do
        repo_local_dir="${OPT_REPO_CACHE_DIR}/${repo_name}.git"
        if [ ! -d "${repo_local_dir}" ]; then
            echo "- error: ${repo_local_dir} is expected to exist"
            exit 1
        fi

        if [ ! -f "${repo_local_dir}/go.sum" ]; then
            echo " - WARN: repo='${repo_name}' no module-based, skipped for now"
            continue
        fi

        if yq ".broken-package-names-to-exclude[]" "${CONFIG_FILEPATH}" | grep -q "${repo_name}"; then
            echo " - WARN: repo='${repo_name}' is blacklisted, skipped for now"
            continue
        fi

        ### TODO(?): --workdir for `doc2go`
        if ! pushd "${repo_local_dir}" > /dev/null; then
            echo " - error: failed to switch dir to '${repo_local_dir}'"
            exit 1
        fi

        echo "- info: doc2go for repo='${repo_name}'"
        if ! doc2go -pkg-doc github.com/"${OPT_GITHUB_ORG_NAME}"="/{{.ImportPath}}" -out "${OPT_WWW_ROOT_DIR}" ./...; then
            echo "- error: generation failed, see doc2go's error"
            if ! popd; then
                echo " - error: failed to return back to '${SELF_DIR}'"
            fi
            exit 1
        fi
        if ! popd > /dev/null; then
            echo "- error: failed to return back to '${SELF_DIR}'"
            exit 1
        fi

        if ! echo "${repo_name}" >> "${REPOS_WITH_GENERATED_DOCS}"; then
            echo "- error: failed to updated '${REPOS_WITH_GENERATED_DOCS}'"
            exit 1
        fi
    done < "${ALREADY_UPDATED_REPOS_CACHE}"
else
    echo "+ dev: doc2go step skipped"
fi

cleanup() {
    if [ -f "${TMP_INDEX_FILEPATH}" ]; then
        rm -f "${TMP_INDEX_FILEPATH}"
    fi
}
trap cleanup EXIT

if ! TMP_INDEX_FILEPATH=$(mktemp); then
    echo "- error: failed to generate temporary file"
    exit 1
fi
echo "${OPT_INDEX_TEMPLATE}" > "${TMP_INDEX_FILEPATH}"

while read -r repo_name; do
    package_url="github.com/${OPT_GITHUB_ORG_NAME}/${repo_name}"

    echo "- info: adding ${package_url} to the index"

    if [ ! -d "${OPT_WWW_ROOT_DIR}/${package_url}" ]; then
        echo "- error: no doc is generated for ${package_url} in ${OPT_WWW_ROOT_DIR}"
        exit 1
    fi

    # shellcheck disable=SC2086
    package_url_suffix="$(echo ${package_url} | tr '/' '-')"
    tmp_gawk_result="${TMP_INDEX_FILEPATH}.${package_url_suffix}"
    if ! gawk \
        -v PACKAGE_URL_VAR="${package_url}" \
        '/%PACKAGE_URL%/ {orig=$0; gsub(/%PACKAGE_URL%/, PACKAGE_URL_VAR, orig); print orig;}; {print}' \
        "${TMP_INDEX_FILEPATH}" > "${tmp_gawk_result}"; then
        echo " + error: template substitution failed"
        exit 1
    fi
    if ! mv "${tmp_gawk_result}" "${TMP_INDEX_FILEPATH}"; then
        echo " + error: failed to restore temporary index template"
        exit 1
    fi
done < "${REPOS_WITH_GENERATED_DOCS}"

###
### Finalize index: remove all placeholders from the template
###
if ! gawk '/%.*%/ {next}; {print}' "${TMP_INDEX_FILEPATH}" > "${OPT_WWW_ROOT_DIR}/index.html"; then
    echo " + error: failed to cleanup template placeholders from ${TMP_INDEX_FILEPATH}"
    exit 1
fi

echo "-- DONE"
