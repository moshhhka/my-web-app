#!/bin/bash



APP_NAME=""

VERSION=""

ENV=""

REPO_URL="https://github.com/moshhhka/my-web-app.git" 

PORT="8080"

HEALTH_URL="http://localhost:$PORT"



for i in "$@"; do

  case $i in

    --app=*)     APP_NAME="${i#*=}" ;;

    --version=*) VERSION="${i#*=}"  ;;

    --env=*)     ENV="${i#*=}"      ;;

  esac

done



if [[ -z "$APP_NAME" || -z "$VERSION" || -z "$ENV" ]]; then

    echo "Ошибка: Неверные аргументы. Пример: ./deploy.sh --app=myapp --version=1.2.3 --env=production"

    exit 1

fi



echo "Проверка зависимостей..."

for cmd in git docker nginx; do

    if ! command -v $cmd &> /dev/null; then

        echo "Ошибка: $cmd не найден. Убедись, что он установлен и есть в PATH."

        exit 1

    fi

done



echo "Получение исходного кода..."

if [ ! -d "$APP_NAME" ]; then

    git clone "$REPO_URL" "$APP_NAME" || { echo "Ошибка клонирования"; exit 1; }

else

    cd "$APP_NAME" && git pull && cd ..

fi



echo "Бэкап текущей версии..."

if docker image inspect "${APP_NAME}:latest" &> /dev/null; then

    docker tag "${APP_NAME}:latest" "${APP_NAME}:backup"

    echo "Предыдущая версия сохранена как :backup"

else

    echo "Первый деплой, бэкап не требуется."

fi



echo "Сборка и запуск версии $VERSION..."

docker build -t "${APP_NAME}:${VERSION}" -t "${APP_NAME}:latest" "./$APP_NAME"



if [ $? -eq 0 ]; then

    docker stop "$APP_NAME" 2>/dev/null

    docker rm "$APP_NAME" 2>/dev/null

    

    docker run -d --name "$APP_NAME" -p "$PORT:80" "${APP_NAME}:latest"

else

    echo "Критическая ошибка сборки образа!"

    exit 1

fi



echo "Проверка здоровья приложения..."

sleep 5 



HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$HEALTH_URL")



if [ "$HTTP_STATUS" -eq 200 ]; then

    echo "УСПЕХ: Приложение $APP_NAME версии $VERSION развернуто на $ENV."

else

    echo "ОШИБКА: Статус ответа $HTTP_STATUS. Начинаю откат..."

    

    docker stop "$APP_NAME" 2>/dev/null

    docker rm "$APP_NAME" 2>/dev/null

    

    if docker image inspect "${APP_NAME}:backup" &> /dev/null; then

        docker run -d --name "$APP_NAME" -p "$PORT:80" "${APP_NAME}:backup"

        echo "ОТКАТ ВЫПОЛНЕН: Работает предыдущая версия."

    else

        echo "ОТКАТ НЕВОЗМОЖЕН: Нет резервной копии образа."

    fi

    exit 1

fi
