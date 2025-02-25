#!/bin/sh

# Цвета для вывода сообщений
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # Без цвета

# Текущая версия скрипта
VERSION="2.0.2"

# Функция для вывода важного сообщения в рамке из ####
print_important() {
    local text="$1"
    local len=${#text}
    # Создаем рамку длиной на 4 символа длиннее текста
    local border=$(printf '%*s' "$((len + 4))" '' | tr ' ' '#')
    printf "${YELLOW}${border}\n# $text #\n${border}\n${NC}"
}

# Вывод версии скрипта
printf "${GREEN}Версия скрипта: $VERSION${NC}\n"

# Вывод версии установленного Xray (если существует)
if [ -x /opt/sbin/xray ]; then
    FULL_XRAY_VERSION=$(/opt/sbin/xray version 2>/dev/null | head -n 1)
    CURRENT_XRAY_VERSION=$(echo "$FULL_XRAY_VERSION" | awk '{print $2}')
    print_important "Установленная версия Xray: $FULL_XRAY_VERSION"
else
    print_important "Xray не установлен."
fi

# Функция для вывода справки
show_help() {
    printf "${GREEN}Использование: ${GREEN}./install_xray.sh ${YELLOW}{command}${NC}\n\n"
    printf "${GREEN}Команды:${NC}\n"
    printf "  ${YELLOW}update|-u${NC}        - Обновить Xray до последней версии.\n"
    printf "  ${YELLOW}<без команды>${NC}    - Вывести список последних 10 релизов Xray для выбора.\n"
    printf "  ${YELLOW}recover|-r${NC}       - Восстановить Xray из резервной копии.\n"
    printf "  ${YELLOW}task HH:MM day${NC}   - Запланировать обновление Xray. Если day = 8, то задание будет выполнено ежедневно.\n"
    printf "  ${YELLOW}task 0${NC}           - Удалить запланированное обновление.\n"
    printf "  ${YELLOW}help|-h${NC}          - Показать это сообщение.\n"
}

# Функция для отключения обновлений Xkeen
disable_xkeen_update() {
    printf "${YELLOW}Отключение автоматических обновлений Xkeen...${NC}\n"
    # Отключаем обновление через xkeen без вывода сообщений
    xkeen -dxc > /dev/null 2>&1
    printf "${GREEN}Автоматическое обновление Xray через Xkeen отключено, чтобы предотвратить откат до версии 1.8.4.${NC}\n"
}

# Определение архитектуры процессора
ARCH=$(opkg print-architecture | grep -vE '(all|_kn)' | awk '{ print $2 }' | cut -d- -f1)
printf "${GREEN}Определенная архитектура: $ARCH${NC}\n"

# Дополнительная информация о процессоре для проверки
lscpu | grep -E 'Architecture|Model name|CPU(s)'

# Определение действия в зависимости от аргумента
ACTION="$1"
VERSION_ARG="$2"

if [ "$ACTION" = "update" ] || [ "$ACTION" = "-u" ]; then
    ACTION="update" # Явное задание ACTION="update" для обработки далее
elif [ -z "$ACTION" ]; then
    ACTION="list_releases" # Если аргумент не указан, действие - вывод списка релизов
fi

if [ "$ACTION" = "task" ]; then
    TIME=$2
    DAY=$3

    # Если введено время "0", удаляем задачу cron
    if [ "$TIME" = "0" ]; then
        crontab -l | grep -v './install_xray.sh update' | crontab -
        printf "${GREEN}Все задачи обновления Xray удалены.${NC}\n"
        exit 0
    fi

    # Проверка формата времени (HH:MM)
    if echo "$TIME" | grep -Eq '^[0-9]{1,2}:[0-9]{1,2}$'; then
        MINUTE=$(echo "$TIME" | cut -d':' -f2)
        HOUR=$(echo "$TIME" | cut -d':' -f1)
    else
        printf "${RED}Укажите корректное время (HH:MM или H:M).${NC}\n"
        exit 1
    fi

    # Проверка корректности дня (0-7 или 8 для ежедневного выполнения)
    if [ "$DAY" -lt 0 ] || [ "$DAY" -gt 8 ]; then
        printf "${RED}Укажите корректный день (0-7 для дней недели или 8 для ежедневного выполнения).${NC}\n"
        exit 1
    fi

    if [ "$DAY" -eq 8 ]; then
        DAY="*"
    elif [ "$DAY" -eq 7 ]; then
        DAY=0
    fi

    # Удаляем старые задачи cron, связанные с обновлением
    crontab -l | grep -v './install_xray.sh update' | crontab -
    (crontab -l 2>/dev/null; echo "$MINUTE $HOUR * * $DAY ./install_xray.sh update") | crontab -

    DAY_NAME=""
    case $DAY in
        0) DAY_NAME="воскресенье" ;;
        1) DAY_NAME="понедельник" ;;
        2) DAY_NAME="вторник" ;;
        3) DAY_NAME="среда" ;;
        4) DAY_NAME="четверг" ;;
        5) DAY_NAME="пятница" ;;
        6) DAY_NAME="суббота" ;;
        *) DAY_NAME="ежедневно" ;;
    esac

    printf "${GREEN}Задача обновления Xray запланирована на $TIME в день $DAY_NAME.${NC}\n"

elif [ "$ACTION" = "update" ]; then
    printf "${GREEN}Обновление Xray до последней версии...${NC}\n"

    URL_BASE="https://github.com/XTLS/Xray-core/releases/latest/download"

    case $ARCH in
        "aarch64")
            URL="$URL_BASE/Xray-linux-arm64-v8a.zip"
            ARCHIVE="Xray-linux-arm64-v8a.zip"
            ;;
        "mips")
            URL="$URL_BASE/Xray-linux-mips32.zip"
            ARCHIVE="Xray-linux-mips32.zip"
            ;;
        "mipsle"|"mipsel")
            URL="$URL_BASE/Xray-linux-mips32le.zip"
            ARCHIVE="Xray-linux-mips32le.zip"
            ;;
        "mips64")
            URL="$URL_BASE/Xray-linux-mips64.zip"
            ARCHIVE="Xray-linux-mips64.zip"
            ;;
        "mips64le")
            URL="$URL_BASE/Xray-linux-mips64le.zip"
            ARCHIVE="Xray-linux-mips64le.zip"
            ;;
        *)
            printf "${RED}Неизвестная архитектура: $ARCH${NC}\n"
            exit 1
            ;;
    esac

    printf "${GREEN}Остановка xkeen...${NC}\n"
    xkeen -stop

    # Убеждаемся, что каталог /opt/sbin существует
    mkdir -p /opt/sbin

    # Создаем каталог для резервных копий
    BACKUP_DIR="/opt/backups"
    mkdir -p "$BACKUP_DIR"

    BACKUP_FILE="$BACKUP_DIR/xray_backup_v1.8.4"
    if [ -f /opt/sbin/xray ]; then
        if [ ! -f "$BACKUP_FILE" ]; then
            printf "${GREEN}Архивация существующего файла xray...${NC}\n"
            mv /opt/sbin/xray "$BACKUP_FILE"
        else
            printf "${YELLOW}Резервная копия с именем xray_backup_v1.8.4 уже существует.${NC}\n"
        fi
    fi

    # Резервное копирование файла 02_transport.json, если версия Xray 1.8.4
    if [ "$CURRENT_XRAY_VERSION" = "1.8.4" ]; then
        printf "${GREEN}Резервное копирование файла 02_transport.json...${NC}\n"
        if [ -f /opt/etc/xray/configs/02_transport.json ]; then
            mv /opt/etc/xray/configs/02_transport.json "$BACKUP_DIR/02_transport.json.backup"
            printf "${GREEN}Резервное копирование файла 02_transport.json прошло успешно.${NC}\n"
        else
            printf "${RED}Файл 02_transport.json не найден.${NC}\n"
        fi
    fi

    printf "${GREEN}Скачивание $ARCHIVE...${NC}\n"
    curl -s -S -L -o /tmp/$ARCHIVE $URL

    printf "${GREEN}Извлечение xray из $ARCHIVE...${NC}\n"
    TEMP_DIR=$(mktemp -d)
    unzip -j /tmp/$ARCHIVE xray -d $TEMP_DIR

    printf "${GREEN}Перемещение xray в /opt/sbin...${NC}\n"
    mv $TEMP_DIR/xray /opt/sbin/xray

    printf "${GREEN}Установка прав доступа...${NC}\n"
    chmod 755 /opt/sbin/xray

    printf "${GREEN}Очистка...${NC}\n"
    rm -rf $TEMP_DIR
    rm /tmp/$ARCHIVE

    printf "${GREEN}Запуск xkeen...${NC}\n"
    xkeen -start

    disable_xkeen_update

    printf "${GREEN}Обновление до последней версии завершено.${NC}\n"


elif [ "$ACTION" = "list_releases" ]; then
    VERSION_ARG=$2

    # Если версия не указана, запускаем интерактивный диалог выбора релиза
    if [ -z "$VERSION_ARG" ]; then
        printf "${GREEN}Получение списка последних 10 релизов Xray...${NC}\n"
        RELEASES_JSON=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases?per_page=10)
        if [ -z "$RELEASES_JSON" ]; then
            printf "${RED}Не удалось получить список релизов. Проверьте соединение с интернетом.${NC}\n"
            exit 1
        fi

        RELEASE_TAGS=$(echo "$RELEASES_JSON" | grep -oE '"tag_name":\s*"[^"]+"' | sed -E 's/"tag_name":\s*"([^"]+)"/\1/')
        if [ -z "$RELEASE_TAGS" ]; then
            printf "${RED}Список релизов пуст.${NC}\n"
            exit 1
        fi

        printf "\n${GREEN}Список последних релизов:${NC}\n"
        echo "$RELEASE_TAGS" | awk '{printf "%2d) %s\n", NR, $0}'

        printf "\n${GREEN}Введите порядковый номер релиза (от 1 до 10) или введите \"m\" для ручного ввода версии: ${NC}"
        read choice

        if [ "$choice" = "m" ]; then
            printf "${GREEN}Введите номер версии (например, 25.1.30): ${NC}"
            read manual_version
            VERSION_ARG="$manual_version"
        else
            if ! echo "$choice" | grep -Eq '^[0-9]+$'; then
                printf "${RED}Некорректный ввод. Ожидался номер или m.${NC}\n"
                exit 1
            fi
            version_selected=$(echo "$RELEASE_TAGS" | sed -n "${choice}p")
            if [ -z "$version_selected" ]; then
                printf "${RED}Выбранный номер вне диапазона.${NC}\n"
                exit 1
            fi
            VERSION_ARG="$version_selected"
        fi
    fi

    case $VERSION_ARG in
        v*) VERSION_PATH="$VERSION_ARG" ;;
        *) VERSION_PATH="v$VERSION_ARG" ;;
    esac

    URL_BASE="https://github.com/XTLS/Xray-core/releases/download/$VERSION_PATH"

    case $ARCH in
        "aarch64")
            URL="$URL_BASE/Xray-linux-arm64-v8a.zip"
            ARCHIVE="Xray-linux-arm64-v8a.zip"
            ;;
        "mips")
            URL="$URL_BASE/Xray-linux-mips32.zip"
            ARCHIVE="Xray-linux-mips32.zip"
            ;;
        "mipsle"|"mipsel")
            URL="$URL_BASE/Xray-linux-mips32le.zip"
            ARCHIVE="Xray-linux-mips32le.zip"
            ;;
        "mips64")
            URL="$URL_BASE/Xray-linux-mips64.zip"
            ARCHIVE="Xray-linux-mips64.zip"
            ;;
        "mips64le")
            URL="$URL_BASE/Xray-linux-mips64le.zip"
            ARCHIVE="Xray-linux-mips64le.zip"
            ;;
        *)
            printf "${RED}Неизвестная архитектура: $ARCH${NC}\n"
            exit 1
            ;;
    esac

    printf "${GREEN}Остановка xkeen...${NC}\n"
    xkeen -stop

    # Убеждаемся, что каталог /opt/sbin существует
    mkdir -p /opt/sbin

    # Создаем каталог для резервных копий
    BACKUP_DIR="/opt/backups"
    mkdir -p "$BACKUP_DIR"

    BACKUP_FILE="$BACKUP_DIR/xray_backup_v1.8.4"
    if [ -f /opt/sbin/xray ]; then
        if [ ! -f "$BACKUP_FILE" ]; then
            printf "${GREEN}Архивация существующего файла xray...${NC}\n"
            mv /opt/sbin/xray "$BACKUP_FILE"
        else
            printf "${YELLOW}Резервная копия с именем xray_backup_v1.8.4 уже существует.${NC}\n"
        fi
    fi

    # Резервное копирование файла 02_transport.json, если версия Xray 1.8.4
    if [ "$CURRENT_XRAY_VERSION" = "1.8.4" ]; then
        printf "${GREEN}Резервное копирование файла 02_transport.json...${NC}\n"
        if [ -f /opt/etc/xray/configs/02_transport.json ]; then
            mv /opt/etc/xray/configs/02_transport.json "$BACKUP_DIR/02_transport.json.backup"
            printf "${GREEN}Резервное копирование файла 02_transport.json прошло успешно.${NC}\n"
        else
            printf "${RED}Файл 02_transport.json не найден.${NC}\n"
        fi
    fi

    printf "${GREEN}Скачивание $ARCHIVE...${NC}\n"
    curl -s -S -L -o /tmp/$ARCHIVE $URL

    printf "${GREEN}Извлечение xray из $ARCHIVE...${NC}\n"
    TEMP_DIR=$(mktemp -d)
    unzip -j /tmp/$ARCHIVE xray -d $TEMP_DIR

    printf "${GREEN}Перемещение xray в /opt/sbin...${NC}\n"
    mv $TEMP_DIR/xray /opt/sbin/xray

    printf "${GREEN}Установка прав доступа...${NC}\n"
    chmod 755 /opt/sbin/xray

    printf "${GREEN}Очистка...${NC}\n"
    rm -rf $TEMP_DIR
    rm /tmp/$ARCHIVE

    printf "${GREEN}Запуск xkeen...${NC}\n"
    xkeen -start

    disable_xkeen_update

    printf "${GREEN}Обновление до версии ${VERSION_ARG} завершено.${NC}\n"


elif [ "$ACTION" = "recover" ] || [ "$ACTION" = "-r" ]; then
    printf "${GREEN}Остановка xkeen...${NC}\n"
    xkeen -stop

    BACKUP_FILE="/opt/backups/xray_backup_v1.8.4"
    if [ -f "$BACKUP_FILE" ]; then
        printf "${GREEN}Восстановление оригинального файла xray...${NC}\n"
        mv "$BACKUP_FILE" /opt/sbin/xray
        chmod 755 /opt/sbin/xray
    else
        printf "${RED}Резервная копия не найдена. Восстановление невозможно.${NC}\n"
        exit 1
    fi

    # Восстановление файла 02_transport.json
    BACKUP_TRANSPORT_FILE="/opt/backups/02_transport.json.backup"
    if [ -f "$BACKUP_TRANSPORT_FILE" ]; then
        printf "${GREEN}Восстановление файла 02_transport.json...${NC}\n"
        mv "$BACKUP_TRANSPORT_FILE" /opt/etc/xray/configs/02_transport.json
        printf "${GREEN}Восстановление файла 02_transport.json прошло успешно.${NC}\n"
    else
        printf "${RED}Резервная копия файла 02_transport.json не найдена.${NC}\n"
    fi

    printf "${GREEN}Запуск xkeen...${NC}\n"
    xkeen -start

    printf "${GREEN}Восстановление завершено.${NC}\n"

else
    show_help
    exit 0
fi
