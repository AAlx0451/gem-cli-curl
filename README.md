# gem-cli-curl

**ЗАВИСИМОСТИ**: перед быстрым запуском найдите способ установить jq, curl, toilet, figlet в вашей системе 

## Быстрый запуск 

1. Экспортируйте ваш API ключ из [AI Studio](https://aistudio.google.com/apikey): `export GOOGLE_API_KEY=aaaaaaaaaaa`

2. Скачайте скрипт:
   `curl -o gem-cli.sh https://raw.githubusercontent.com/AAlx0451/gem-cli-curl/refs/heads/main/gem-cli.sh`

3. Запустите скрипт:
   `bash gem-cli.sh`
   

## Стандартная установка 

1. Клонируйте репозиторий: `git clone https://github.com/AAlx0451/gem-cli-curl && cd gem-cli-curl`
   
2. Установите зависимости:
   * Debian/Ubuntu:
     `sudo apt install curl jq figlet toilet`

   * Android:
     `apt install curl jq figlet toilet`

   * Arch:
     `sudo pacman -S curl jq figlet toilet`

   * Другая платформа:
     Найдите способ установки curl, jq, figlet и toilet для вашей системы
     
3. Сделайте скрипт исполняемым:
   `chmod +x gem-cli.sh`

4. Экспортируйте ваш API ключ из [AI Studio](https://aistudio.google.com/apikey): `echo "export GOOGLE_API_KEY=aaaaaaaaaaa" >> ~/.bashrc`

5. Добавьте скрипт в PATH для глобального использования:
   ```bash
   mkdir -p "$HOME/.local/bin" && cp ./gem-cli.sh "$HOME/.local/bin/gem-cli" && chmod +x "$HOME/.local/bin/gem-cli" && (grep -qF 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc || echo -e '\n# Add ~/.local/bin to PATH for user scripts\nexport PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc) && echo -e '\n\033[1;32mУспешно установлено!\033[0m\n\n\033[1;33mДЕЙСТВИЕ:\033[0m Перезапустите ваш терминал или выполните команду \033[1;36msource ~/.bashrc\033[0m, чтобы завершить установку.'
   ```

6. Запустите скрипт:
   `gem-cli`

## Функции

* Использование нескольких моделей на выбор: Gemini 2.0 Flash, Gemini 2.5 Flash-Lite, Gemini 2.5 Flash, Gemini 2.5 Pro

* Генерация изображений через Gemini 2.0 Flash
  
* Многострочный ввод

* Многоступенчатая генерация изображений, где промпт придумывает одна модель, вторая генерирует, третья придумывает название для файла, а четвертая говорит, может ли он быть пугающим 
