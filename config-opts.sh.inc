# shellcheck disable=SC2148

if ! OPT_GITHUB_ORG_NAME=$(yq '.github-org-name // ""' < "${CONFIG_FILEPATH}"); then
    echo "- error: failed to retrieve github-org-name from config"
    exit 1
fi
if [ -z "${OPT_GITHUB_ORG_NAME}" ]; then
    echo "- error: github-org-name is not defined"
    exit 1
fi

if ! OPT_WWW_ROOT_DIR=$(yq '.www-root-dir // ""' < "${CONFIG_FILEPATH}"); then
    echo "- error: failed to retrieve www-root-dir from config"
    exit 1
fi
if [ -z "${OPT_WWW_ROOT_DIR}" ]; then
    echo "- error: www-root-dir is not defined"
    exit 1
fi
OPT_WWW_ROOT_DIR="$(realpath "${OPT_WWW_ROOT_DIR}")"
if [ ! -d "${OPT_WWW_ROOT_DIR}" ]; then
    echo "- error: ${OPT_WWW_ROOT_DIR} is not existent as well"
    exit 1
fi

if ! OPT_REPO_CACHE_DIR=$(yq '.cache-dir // ""' < "${CONFIG_FILEPATH}"); then
    echo "- error: failed to retrieve cache-dir from config"
    exit 1
fi
if [ -z "${OPT_REPO_CACHE_DIR}" ]; then
    echo "- error: cache-dir is not defined"
    exit 1
fi
if ! mkdir -p "${OPT_REPO_CACHE_DIR}"; then
    echo "- error: failed to ensure cache-dir='${OPT_REPO_CACHE_DIR}' exists"
    exit 1
fi

if ! OPT_INDEX_TEMPLATE="$(yq '.index-template // ""' < "${CONFIG_FILEPATH}")"; then
    echo "- error: failed to retrieve index-template from config"
    exit 1
fi
if [ -z "${OPT_INDEX_TEMPLATE}" ]; then
    echo "- error: index-template is empty"
    exit 1
fi
