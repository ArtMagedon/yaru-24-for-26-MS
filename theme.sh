#!/bin/bash

set -euo pipefail

# ============================================================
# Настройки
# ============================================================

SOURCE="$HOME/yaru-24/usr/share/icons"
REPO="$HOME/.themes/yaru-24-places"
ICON_DIR="$HOME/.local/share/icons"

THEMES=(
    "Yaru"
    "Yaru-bark"
    "Yaru-blue"
    "Yaru-dark"
    "Yaru-magenta"
    "Yaru-olive"
    "Yaru-prussiangreen"
    "Yaru-purple"
    "Yaru-red"
    "Yaru-sage"
    "Yaru-viridian"
)

# ============================================================
# Дополнительные файлы, которые нужно копировать из Yaru 24
#
# Пути указываются относительно конкретной темы Yaru.
#
# Примеры:
#
# "*/apps/filemanager-app.png"
# "256x256/apps/foo.png"
# "*/places/folder.png"
# "scalable/places/folder.svg"
#
# Можно добавлять сколько угодно строк.
# ============================================================

COPY_PATHS=(
    "*/apps/filemanager-app.png"
    "*/apps/file-manager.png"
)

# ============================================================
# Подготовка
# ============================================================

mkdir -p "$REPO"
mkdir -p "$ICON_DIR"

echo
echo "Источник Yaru 24:"
echo "  $SOURCE"
echo
echo "Репозиторий:"
echo "  $REPO"
echo
echo "Ссылки:"
echo "  $ICON_DIR"
echo
echo "Дополнительное копирование:"

for PATTERN in "${COPY_PATHS[@]}"; do
    echo "  $PATTERN"
done

echo

# ============================================================
# Проверка источника
# ============================================================

if [ ! -d "$SOURCE" ]; then
    echo "ОШИБКА: не найден источник Yaru 24:"
    echo "$SOURCE"
    exit 1
fi

# ============================================================
# Вспомогательная функция
#
# Добавляет директорию в список только один раз.
# ============================================================

add_directory() {
    local DIRECTORY="$1"

    for EXISTING in "${DIRECTORIES[@]}"; do
        if [ "$EXISTING" = "$DIRECTORY" ]; then
            return
        fi
    done

    DIRECTORIES+=("$DIRECTORY")
}

# ============================================================
# Создание тем
# ============================================================

for BASE_THEME in "${THEMES[@]}"; do

    SOURCE_THEME="$SOURCE/$BASE_THEME"

    if [ "$BASE_THEME" = "Yaru" ]; then
        NEW_THEME="Yaru-24"
    else
        NEW_THEME="Yaru-24-${BASE_THEME#Yaru-}"
    fi

    TARGET_THEME="$REPO/$NEW_THEME"
    ICON_LINK="$ICON_DIR/$NEW_THEME"

    echo "========================================"
    echo "База:       $BASE_THEME"
    echo "Новая тема: $NEW_THEME"
    echo "========================================"

    if [ ! -d "$SOURCE_THEME" ]; then
        echo "ОШИБКА: не найден:"
        echo "  $SOURCE_THEME"
        exit 1
    fi

    # --------------------------------------------------------
    # Удаляем старую версию нашей темы
    # --------------------------------------------------------

    if [ -e "$TARGET_THEME" ] || [ -L "$TARGET_THEME" ]; then
        rm -rf "$TARGET_THEME"
    fi

    mkdir -p "$TARGET_THEME"

    # Массив директорий для index.theme
    DIRECTORIES=()

    # --------------------------------------------------------
    # Копируем places
    # --------------------------------------------------------

    mapfile -t PLACES_DIRS < <(
        find "$SOURCE_THEME" \
            -type d \
            -name "places" \
            -print \
            | sort
    )

    if [ "${#PLACES_DIRS[@]}" -eq 0 ]; then
        echo "ПРЕДУПРЕЖДЕНИЕ: places не найден."
    fi

    for PLACES_DIR in "${PLACES_DIRS[@]}"; do

        RELATIVE="${PLACES_DIR#$SOURCE_THEME/}"
        DEST_DIR="$TARGET_THEME/$RELATIVE"
        
        echo "  Копируем $RELATIVE"
        #echo "  $PLACES_DIR ___ $DEST_DIR"

        mkdir -p "$(dirname "$DEST_DIR")"
        cp -a "$PLACES_DIR" "$DEST_DIR"

        add_directory "$RELATIVE"

    done

    # --------------------------------------------------------
    # Копируем дополнительные файлы
    # --------------------------------------------------------

    for PATTERN in "${COPY_PATHS[@]}"; do

        FOUND=0
        tfile=""
        while IFS= read -r -d '' FILE; do
            tfile=$FILE
            FOUND=1

            RELATIVE="${FILE#$SOURCE_THEME/}"
            DEST="$TARGET_THEME/$RELATIVE"

            echo "  Копируем дополнительный файл: $RELATIVE"
            echo "  $FILE  ->  $DEST"

            mkdir -p "$(dirname "$DEST")"
            cp -a "$FILE" "$DEST"

            DIRECTORY="${RELATIVE%/*}"

            add_directory "$DIRECTORY"
            if [ "$(basename "$FILE")" = "filemanager-app.png" ]; then

                LINK="$TARGET_THEME/$DIRECTORY/file-manager.png"

                rm -f "$LINK"

                ln -s "filemanager-app.png" "$LINK"

                echo "  Создана ссылка: $RELATIVE"
                echo "  $LINK -> filemanager-app.png"

            fi

        done < <(
            find "$SOURCE_THEME" \
                -type f \
                -path "$SOURCE_THEME/$PATTERN" \
                -print0
        )

        if [ "$FOUND" -eq 0 ]; then
            echo "  Не найдено: $PATTERN"
        fi

    done

    # --------------------------------------------------------
    # Создаем index.theme
    # --------------------------------------------------------

    {
        echo "[Icon Theme]"
        echo "Name=$NEW_THEME"
        echo "Comment=Yaru 24 icons"
        echo "Inherits=$BASE_THEME"

        echo -n "Directories="

        (
            IFS=,
            echo "${DIRECTORIES[*]}"
        )

        echo

        for DIRECTORY in "${DIRECTORIES[@]}"; do

            echo
            echo "[$DIRECTORY]"

            SIZE_DIR="${DIRECTORY%%/*}"

            case "$SIZE_DIR" in

                scalable)
                    echo "Size=48"
                    echo "Type=Scalable"
                    ;;

                *)
                    if [[ "$SIZE_DIR" =~ ^([0-9]+)x([0-9]+)$ ]]; then
                        echo "Size=${BASH_REMATCH[1]}"
                        echo "Type=Fixed"
                    else
                        echo "Type=Fixed"
                    fi
                    ;;

            esac

        done

    } > "$TARGET_THEME/index.theme"

    # --------------------------------------------------------
    # Создаем ссылку в ~/.local/share/icons
    # --------------------------------------------------------

    if [ -e "$ICON_LINK" ] || [ -L "$ICON_LINK" ]; then
        rm -rf "$ICON_LINK"
    fi

    ln -s "$TARGET_THEME" "$ICON_LINK"

    echo
    echo "  Ссылка:"
    echo "  $ICON_LINK -> $TARGET_THEME"
    echo

done

# ============================================================
# Итог
# ============================================================

echo
echo "========================================"
echo "ГОТОВО"
echo "========================================"
echo

echo "Темы в:"
echo "  $REPO"

echo
echo "Ссылки в:"
echo "  $ICON_DIR"

echo
echo "Созданные темы:"

find "$REPO" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -name 'Yaru-24*' \
    -printf '  %f\n' \
    | sort

echo
echo "Проверка ссылок:"

find "$ICON_DIR" \
    -maxdepth 1 \
    -type l \
    -lname "$REPO/*" \
    -printf '  %f -> %l\n' \
    | sort