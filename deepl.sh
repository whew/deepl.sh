#!/bin/bash

# setup #######################################################################
LANGUAGE=${DEEPL_TARGET:-DE}
PARSER="jq"
if ! type "$PARSER" >/dev/null 2>&1; then
  PARSER="/usr/bin/jq"
fi

# parameters ##################################################################
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case "$key" in
  -l | --lang)
    LANGUAGE="$2"
    shift # past argument
    shift # past value
    ;;
  *) # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift              # past argument
    ;;
  esac
done
set -- "${POSITIONAL[@]:-}" # restore positional parameters

# help ########################################################################
if [ -z "$1" ]; then
  echo "SYNTAX : $0 [-l language] <query>" >&2
  echo "Example: $0 -l DE \"This is just an example.\""
  exit 1
fi

# process query ###############################################################
query="$(echo "$1")"

# prepare query ###############################################################
data='{"jsonrpc":"2.0","method": "LMT_handle_jobs","params":{"jobs":[{"kind":"default","raw_en_sentence":"'"$query"'","raw_en_context_before":[],"raw_en_context_after":[],"quality":"fast"}],"lang":{"user_preferred_langs":["EN"],"source_lang_user_selected":"auto","target_lang":"'"${LANGUAGE:-DE}"'"},"priority":-1,"timestamp":1557063997314},"id":79120002}'
HEADER=(
  --compressed
  -H 'Origin: https://www.deepl.com'
  -H 'Referer: https://www.deepl.com/translator'
  -H 'Accept: */*'
  -H 'Content-Type: text/plain'
  -H 'Accept-Language: en-us'
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1 Safari/605.1.15'
)

# pre query ###################################################################
curl -s 'https://www.deepl.com/PHP/backend/clientState.php?request_type=jsonrpc&il=EN' \
  "${HEADER[@]}" \
  --data-binary '{"jsonrpc":"2.0","method":"getClientState","params":{"v":"20180814"},"id":79120001}' >|/dev/null

# query #######################################################################
result=$(curl -s 'https://www2.deepl.com/jsonrpc' \
  "${HEADER[@]}" \
  --data-binary $"$data")

if [[ $result == *'"error":{"code":'* ]]; then
  message=$(echo "$result" | "$PARSER" -r '.["error"]|.message')
  echo "Error: $message"
else
  echo ""
  echo "$result" | "$PARSER" -r '{items: [.result.translations[0].beams[] | {arg:.postprocessed_sentence}]}' | grep -E "arg" | grep -o '".*"' | sed 's/"//g' | sed 's/arg: //g' | sed '0~1 a\\'
fi
##############################################################################
