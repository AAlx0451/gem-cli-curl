#!/bin/bash

# --- Константы и цвета ---
declare -A COLORS=(
    [GEMINI_MAIN]='\033[1;35m' [GEMINI_ACCENT]='\033[0;34m' [USER_INPUT]='\033[1;36m'
    [DIM]='\033[2m'           [RESET]='\033[0m'           [ERROR]='\033[1;31m'
    [WARNING]='\033[95m'
)
BASE_API_URL="https://generativelanguage.googleapis.com/v1/models/"
IMAGE_GENERATION_MODEL="gemini-2.0-flash-preview-image-generation"
WOW_PROMPT_MODEL="gemini-2.5-flash"
DEFAULT_MODEL="gemini-2.0-flash"

# --- Глобальные переменные ---
declare -A MODELS=(
    ["gemini-2.5-pro"]="Самая лучшая модель на рынке"
    ["gemini-2.5-flash"]="Неплохая быстрая дешёвая модель"
    ["gemini-2.5-flash-lite"]="Самая быстрая и дешёвая модель"
)
CURRENT_MODEL_NAME="$DEFAULT_MODEL"
TEMP_CHAT_FILE=$(mktemp)
trap 'rm -f "$TEMP_CHAT_FILE"' EXIT

# --- Вспомогательные функции API ---
function gemini_api_call {
    local model="$1" endpoint_suffix="$2" request_body="$3"
    curl -s -X POST \
        -H "Content-Type: application/json" -H "X-goog-api-key: $GOOGLE_API_KEY" \
        -d "$request_body" \
        "${BASE_API_URL}${model}${endpoint_suffix}"
}

function build_text_request_body {
    jq -n --arg text "$1" '{"contents": [{"parts": [{"text": $text}]}]}'
}

# --- Функции управления чатом и историей ---
function init_chat_history {
    echo '{"contents": []}' > "$TEMP_CHAT_FILE"
}

function add_to_history {
    jq --arg role "$1" --arg text "$2" '.contents += [{"role": $role, "parts": [{"text": $text}]}]' \
        "$TEMP_CHAT_FILE" > tmp.$$.json && mv tmp.$$.json "$TEMP_CHAT_FILE"
}

function confirm_clear_history {
    read -p "$(printf "${COLORS[WARNING]}Вы уверены, что хотите очистить историю чата? (y/N):${COLORS[RESET]} ")" -n 1 -r confirm
    echo
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        init_chat_history
        printf "${COLORS[DIM]}(История чата очищена)${COLORS[RESET]}\n"
    else
        printf "${COLORS[GEMINI_ACCENT]}Очистка истории отменена.${COLORS[RESET]}\n"
    fi
    sleep 1
}

function show_token_count {
    if jq -e '.contents | length == 0' "$TEMP_CHAT_FILE" &>/dev/null; then
        printf "${COLORS[GEMINI_ACCENT]}В истории чата нет сообщений. Количество токенов: 0${COLORS[RESET]}\n"
        sleep 2; return
    fi
    printf "${COLORS[GEMINI_ACCENT]}Считаю токены для %s...${COLORS[RESET]}\n" "$CURRENT_MODEL_NAME"
    
    local request_body; request_body=$(<"$TEMP_CHAT_FILE")
    local response; response=$(gemini_api_call "$CURRENT_MODEL_NAME" ":countTokens" "$request_body")
    local error_message; error_message=$(echo "$response" | jq -r '.error.message // empty')
    
    if [[ -n "$error_message" ]]; then
        printf "${COLORS[ERROR]}Ошибка подсчета токенов:${COLORS[RESET]} %s\n" "$error_message"
    else
        local total_tokens; total_tokens=$(echo "$response" | jq -r '.totalTokens // 0')
        printf "${COLORS[GEMINI_ACCENT]}Текущее количество токенов в диалоге:${COLORS[RESET]} ${COLORS[WARNING]}%s${COLORS[RESET]}\n" "$total_tokens"
    fi
    sleep 3
}

# --- Функции генерации и меню ---
function display_banner {
    local text="Gemini-CLI"
    if command -v toilet &>/dev/null; then toilet -f big --filter metal --termwidth "$text"; elif command -v figlet &>/dev/null; then figlet "$text"; else echo "--- $text ---"; fi
}

function select_model {
    local models_to_display=("${!MODELS[@]}")
    [[ " ${models_to_display[*]} " =~ " ${DEFAULT_MODEL} " ]] || models_to_display+=("$DEFAULT_MODEL")
    [[ " ${models_to_display[*]} " =~ " ${WOW_PROMPT_MODEL} " ]] || models_to_display+=("$WOW_PROMPT_MODEL")
    
    printf "\n${COLORS[GEMINI_ACCENT]}--- Выбор модели (Текущая: ${COLORS[RESET]}%s${COLORS[GEMINI_ACCENT]}) ---${COLORS[RESET]}\n" "$CURRENT_MODEL_NAME"
    for i in "${!models_to_display[@]}"; do
        model_name="${models_to_display[i]}"; desc="${MODELS[$model_name]:-Используется для служебных задач}"
        printf "${COLORS[WARNING]}%d.${COLORS[RESET]} %s (${COLORS[DIM]}%s${COLORS[RESET]})\n" "$((i + 1))" "$model_name" "$desc"
    done
    printf "${COLORS[WARNING]}0.${COLORS[RESET]} Отмена\n"
    read -p "$(printf "${COLORS[USER_INPUT]}Выберите новую модель (1-%d) или 0:${COLORS[RESET]} " "${#models_to_display[@]}")" choice

    if [[ "$choice" -ge 1 && "$choice" -le "${#models_to_display[@]}" ]]; then
        local selected_model="${models_to_display[choice-1]}"
        if [[ "$selected_model" != "$CURRENT_MODEL_NAME" ]]; then
            CURRENT_MODEL_NAME="$selected_model"; init_chat_history
            printf "${COLORS[GEMINI_MAIN]}Модель изменена на: %s. История чата очищена.${COLORS[RESET]}\n" "$CURRENT_MODEL_NAME"
        fi
    fi
}

function show_menu {
    while true; do
        printf "\n${COLORS[GEMINI_ACCENT]}--- Меню ---${COLORS[RESET]}\n"
        printf "${COLORS[WARNING]}1.${RESET_COLOR} Выход из программы\n"
        printf "${COLORS[WARNING]}2.${RESET_COLOR} Сменить модель (%s)\n" "$CURRENT_MODEL_NAME"
        printf "${COLORS[WARNING]}3.${RESET_COLOR} Очистить историю чата\n"
        printf "${COLORS[WARNING]}4.${RESET_COLOR} Показать количество токенов\n"
        printf "${COLORS[WARNING]}0.${RESET_COLOR} Вернуться в чат\n"
        printf "${COLORS[GEMINI_ACCENT]}------------${COLORS[RESET]}\n"
        read -p "$(printf "${COLORS[USER_INPUT]}Выберите опцию:${COLORS[RESET]} ")" choice

        case "$choice" in
            1) return 1 ;; # Сигнал для выхода из основного цикла
            2) select_model ;;
            3) confirm_clear_history ;;
            4) show_token_count ;;
            0) return 0 ;; # Сигнал для продолжения
            *) printf "${COLORS[ERROR]}Неверный выбор. Пожалуйста, введите число от 0 до 4.${COLORS[RESET]}\n" ;;
        esac
    done
}

function generate_image {
    # (Код этой функции не изменился, оставлен для полноты)
    local image_prompt="$1"
    if [ -z "$image_prompt" ]; then
        printf "${COLORS[WARNING]}Укажите промпт для изображения (пример: !image кот в шляпе).${COLORS[RESET]}\n"
        return 1
    fi
    printf "${COLORS[GEMINI_ACCENT]}Gemini (%s):${COLORS[RESET]} ${COLORS[DIM]}Генерирую изображение...${COLORS[RESET]}\n" "$IMAGE_GENERATION_MODEL"
    local image_req_body; image_req_body=$(jq -n --arg prompt "$image_prompt" '{contents: [{parts: [{text: $prompt}]}], "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}}')
    local response; response=$(gemini_api_call "$IMAGE_GENERATION_MODEL" ":generateContent" "$image_req_body")
    local error_message; error_message=$(echo "$response" | jq -r '.error.message // empty')
    if [[ -n "$error_message" ]]; then
        printf "\n${COLORS[ERROR]}Ошибка генерации изображения:${COLORS[RESET]} %s\n" "$error_message"
        return 1
    fi
    local image_base64_data; image_base64_data=$(echo "$response" | jq -r '(.candidates[0].content.parts[] | select(.inlineData) | .inlineData.data) // empty')
    if [[ -z "$image_base64_data" ]]; then
        printf "\n${COLORS[WARNING]}Gemini:${RESET_COLOR} ${COLORS[DIM]}Не удалось получить данные изображения из ответа.${COLORS[RESET]}\n"
        return 1
    fi
    printf "${COLORS[GEMINI_ACCENT]}Gemini (%s):${COLORS[RESET]} ${COLORS[DIM]}Придумываю название файла...${COLORS[RESET]}\n" "$DEFAULT_MODEL"
    local filename_prompt="Create a very short, descriptive filename (lowercase, hyphens, alphanumeric, max 50 chars) for an image from prompt: \"$image_prompt\". Start with 'gemini-' and end with '.png'."
    local filename_body; filename_body=$(build_text_request_body "$filename_prompt")
    local filename_response; filename_response=$(gemini_api_call "$DEFAULT_MODEL" ":generateContent" "$filename_body")
    local suggested_filename; suggested_filename=$(echo "$filename_response" | jq -r '.candidates[0].content.parts[0].text // empty')
    local final_filename; if [[ -n "$suggested_filename" ]]; then
        final_filename=$(echo "$suggested_filename" | tr '[:upper:]' '[:lower:]' | tr -d '\n\r' | sed -E 's/[^a-z0-9.-]+/-/g; s/--+/-/g; s/^-|-$//g' | cut -c 1-50)
        [[ "$final_filename" =~ ^gemini-.*\.png$ ]] || final_filename="gemini-$(basename "$final_filename" .png).png"
    fi
    [[ -z "$final_filename" || "$final_filename" == "gemini-.png" ]] && final_filename="gemini_image_$(date +"%Y%m%d_%H%M%S").png"
    local output_dir="${HOME}/gemini_images"; mkdir -p "$output_dir"; local output_filepath="${output_dir}/${final_filename}"
    if echo "$image_base64_data" | base64 --decode > "$output_filepath"; then
        printf "\n${COLORS[GEMINI_ACCENT]}Изображение сохранено в:${COLORS[RESET]} ${COLORS[WARNING]}%s${COLORS[RESET]}\n" "$output_filepath"
        add_to_history "user" "[Image Prompt]: $image_prompt"; add_to_history "model" "[Image Generated]: $output_filepath"
    else
        printf "\n${COLORS[ERROR]}Ошибка при сохранении изображения.${COLORS[RESET]}\n"; return 1
    fi
}

function wow_command {
    # (Код этой функции не изменился, оставлен для полноты)
    printf "${COLORS[GEMINI_ACCENT]}Gemini (%s):${COLORS[RESET]} ${COLORS[DIM]}Придумываю WOW-промпт...${COLORS[RESET]}\n" "$WOW_PROMPT_MODEL"
    local wow_prompt_req_body; wow_prompt_req_body=$(build_text_request_body "Generate a single, unusual, creative, concise image generation prompt (max 100 chars). Just the prompt, no conversational filler.")
    local wow_prompt_response; wow_prompt_response=$(gemini_api_call "$WOW_PROMPT_MODEL" ":generateContent" "$wow_prompt_req_body")
    local generated_image_prompt; generated_image_prompt=$(echo "$wow_prompt_response" | jq -r '.candidates[0].content.parts[0].text // empty')
    if [[ -z "$generated_image_prompt" ]]; then printf "${COLORS[WARNING]}Gemini:%s ${COLORS[DIM]}Не удалось сгенерировать WOW-промпт.${COLORS[RESET]}\n"; return 1; fi
    printf "${COLORS[DIM]}Сгенерированный промпт: %s${COLORS[RESET]}\n\n" "$generated_image_prompt"
    generate_image "$generated_image_prompt" || return 1
    printf "${COLORS[GEMINI_ACCENT]}Gemini (%s):${COLORS[RESET]} ${COLORS[DIM]}Оцениваю безопасность...${COLORS[RESET]}\n" "$DEFAULT_MODEL"
    local verdict_prompt="Учитывая промпт: \"$generated_image_prompt\", может ли результат быть шокирующим/тревожащим? Ответь 'Да'/'Нет'/'Неоднозначно' и кратко объясни. Начни с 'Вердикт: '."
    local verdict_body; verdict_body=$(build_text_request_body "$verdict_prompt")
    local verdict_response; verdict_response=$(gemini_api_call "$DEFAULT_MODEL" ":generateContent" "$verdict_body")
    local verdict; verdict=$(echo "$verdict_response" | jq -r '.candidates[0].content.parts[0].text // "Не удалось получить вердикт."')
    printf "\n${COLORS[GEMINI_MAIN]}--- Вердикт по безопасности WOW-изображения ---${COLORS[RESET]}\n%s\n${COLORS[GEMINI_MAIN]}------------------------------------------------${COLORS[RESET]}\n\n" "$verdict"
}

# --- Основная логика ---
clear
if [[ -z "$GOOGLE_API_KEY" ]]; then
    printf "${COLORS[ERROR]}Ошибка:${COLORS[RESET]} API-ключ не найден. Установите ${COLORS[WARNING]}GOOGLE_API_KEY${COLORS[RESET]}.\n"
    exit 1
fi
init_chat_history

printf "${COLORS[GEMINI_MAIN]}"; display_banner; printf "${COLORS[RESET]}"
printf "${COLORS[GEMINI_ACCENT]}Привет! Я твой CLI для Google Gemini.${COLORS[RESET]}\n"
printf "${COLORS[GEMINI_ACCENT]}Команды: ${COLORS[WARNING]}!M${COLORS[RESET]} (меню), ${COLORS[WARNING]}!image [промпт]${COLORS[RESET]}, ${COLORS[WARNING]}!wow${COLORS[RESET]}, ${COLORS[WARNING]}!multi${RESET_COLOR} (многострочный ввод).\n\n"

while true; do
    read -p "$(printf "${COLORS[USER_INPUT]}Ты (%s):${COLORS[RESET]} " "$CURRENT_MODEL_NAME")" user_input

    case "$user_input" in
        "!multi")
            printf "${COLORS[WARNING]}Многострочный режим:${COLORS[RESET]} пустая строка завершает ввод.\n"
            user_input=""; while IFS= read -r line && [[ -n "$line" ]]; do user_input+="$line"$'\n'; done
            [[ -z "$user_input" ]] && continue
            ;;
        "!M"|"!m")
            show_menu
            if [[ $? -eq 1 ]]; then
                printf "${COLORS[GEMINI_MAIN]}До свидания!${COLORS[RESET]}\n"; break
            fi
            printf "${COLORS[GEMINI_ACCENT]}Возвращаемся в чат...${COLORS[RESET]}\n"; continue
            ;;
        "!image"*) generate_image "${user_input#*!image }"; continue ;;
        "!wow") wow_command; continue ;;
        "") continue ;;
    esac

    add_to_history "user" "$user_input"
    printf "${COLORS[GEMINI_ACCENT]}Gemini:${COLORS[RESET]} ${COLORS[DIM]}Думаю...${RESET_COLOR}\n"
    
    CHAT_HISTORY=$(<"$TEMP_CHAT_FILE")
    API_RESPONSE=$(gemini_api_call "$CURRENT_MODEL_NAME" ":generateContent" "$CHAT_HISTORY")

    ERROR_MESSAGE=$(echo "$API_RESPONSE" | jq -r '.error.message // empty')
    if [[ -n "$ERROR_MESSAGE" ]]; then
        printf "\n${COLORS[ERROR]}Ошибка API:${COLORS[RESET]} %s\n" "$ERROR_MESSAGE"
        jq '.contents = .contents[:-1]' "$TEMP_CHAT_FILE" > tmp.$$.json && mv tmp.$$.json "$TEMP_CHAT_FILE"
        continue
    fi

    GENERATED_TEXT=$(echo "$API_RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty')
    if [[ -z "$GENERATED_TEXT" ]]; then
        printf "\n${COLORS[WARNING]}Gemini:${RESET_COLOR} ${COLORS[DIM]}Ответ пуст или заблокирован.${COLORS[RESET]}\n"
        jq '.contents = .contents[:-1]' "$TEMP_CHAT_FILE" > tmp.$$.json && mv tmp.$$.json "$TEMP_CHAT_FILE"
        continue
    fi

    add_to_history "model" "$GENERATED_TEXT"
    printf "\n${COLORS[GEMINI_ACCENT]}Gemini:${COLORS[RESET]}\n%s\n\n" "$GENERATED_TEXT"
done
