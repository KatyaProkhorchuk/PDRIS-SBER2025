#!/bin/bash

if ! command -v kubectl &> /dev/null; then
    echo "Ошибка: kubectl не установлен"
    exit 1
fi

wait_for_resource() {
    local resource_type=$1
    local resource_name=$2
    local timeout=120  
    
    echo "Ждемс ${resource_type}/${resource_name}..."
    kubectl wait --for=condition=ready --timeout=${timeout}s ${resource_type}/${resource_name} || {
        echo "Таймаут ожидания ${resource_type}/${resource_name}"
        kubectl describe ${resource_type} ${resource_name}
        exit 1
    }
}


apply_manifests() {
    local components=(
        "configmap.yml"
        "pod.yml"
        "deployment.yml"
        "service.yml"
        "daemonset.yml"
        "cronjob.yml"
    )
    
    for file in "${components[@]}"; do
        local path="helm/${file}"
        if [ -f "$path" ]; then
            echo "Применение ${file}..."
            kubectl apply -f "$path"
            case "$file" in
                "deployment.yaml")
                    wait_for_resource deployment app-deployment
                    ;;
                "daemonset.yaml")
                    wait_for_resource daemonset log-agent
                    ;;
            esac
        else
            echo "файл ${file} не найден"
        fi
    done
}

main() {
    echo "Сборка образа"
    docker build -t custom-app:latest web-app 
    # minikube start # раскоментировать если minikube не запущен
    minikube image load custom-app 
    echo "Начало развертывания..."
    apply_manifests
    
    echo "Проверка сервисов..."
    kubectl get svc,ep -o wide
    
    kubectl get all
}

main "$@"