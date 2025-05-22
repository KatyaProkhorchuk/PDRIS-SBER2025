#!/bin/bash

check_dependencies() {
    if ! command -v kubectl &> /dev/null; then
        echo "Ошибка: kubectl не установлен"
        exit 1
    fi
    
    if ! command -v istioctl &> /dev/null; then
        echo "install istioctl..."
        curl -L https://istio.io/downloadIstio | sh -
        export PATH=$PWD/istio-*/bin:$PATH
        kubectl apply -f istio-*/manifests/charts/base/files/crd-all.gen.yaml 
    fi
}

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

setup_istio() {
    echo "Istio..."
    istioctl install --set profile=demo -y
    kubectl label namespace default istio-injection=enabled
}

apply_manifests() {
    local components=(
        "configmap.yml"
        "pod.yml"
        "deployment.yml"
        "service.yml"
        "daemonset.yml"
        "cronjob.yml"
        "istio/gateway.yml"
        "istio/virtualservice.yml"
        "istio/destinationrule.yml"
    )
    
    for file in "${components[@]}"; do
        local path="helm/${file}"
        if [ -f "$path" ]; then
            echo "Применение ${file}..."
            kubectl apply -f "$path"
            
            case "$file" in
                "deployment.yml")
                    wait_for_resource deployment app-deployment
                    ;;
                "daemonset.yml")
                    wait_for_resource daemonset log-agent
                    ;;
                "istio/gateway.yml")
                    wait_for_resource gateway app-gateway
                    ;;
            esac
        else
            echo "Файл ${file} не найден"
        fi
    done
}

main() {
    check_dependencies
    
    echo "Сборка образа"
    docker build -t custom-app:latest web-app 
    minikube image load custom-app 
    
    setup_istio
    
    echo "Начало развертывания..."
    apply_manifests
    
    echo "Проверка сервисов..."
    kubectl get svc,ep -o wide
    
    echo "Итоговый статус:"
    kubectl get all
    echo "Istio Gateway:"
    kubectl get gateway
    echo "VirtualService:"
    kubectl get virtualservice
}

main "$@"