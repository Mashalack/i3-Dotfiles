#!/bin/bash
# Capturador de pantalla simplificado con slop
# Dependencias: slop, imagemagick, xclip, libnotify (para notify-send)

# Configuración
SAVE_DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$SAVE_DIR"
FILENAME="$SAVE_DIR/$(date +'%Y-%m-%d_%H-%M-%S').png"

# Colores y estilo para slop
SLOP_OPTS="--color=1,1,1,0.4 --bordersize=3 --highlight"

# Función para mostrar notificaciones
show_notification() {
    local title="$1"
    local message="$2"
    
    # Usar notify-send si está disponible
    if command -v notify-send &> /dev/null; then
        notify-send -t 3000 -i camera-photo "$title" "$message"
    else
        echo "📢 $title: $message"
    fi
}

# Función para copiar al portapapeles
copy_to_clipboard() {
    local file="$1"
    
    if command -v xclip &> /dev/null; then
        # Copiar imagen al portapapeles
        if xclip -selection clipboard -t image/png -i "$file" 2>/dev/null; then
            echo "✅ Copiado al portapapeles"
            return 0
        else
            echo "⚠️  No se pudo copiar al portapapeles"
            return 1
        fi
    else
        echo "⚠️  xclip no instalado, no se puede copiar al portapapeles"
        return 1
    fi
}

# Función para captura de región
capture_region() {
    echo "🎯 Selecciona un área con el ratón..."
    
    # Obtener geometría de la selección
    local geometry
    geometry=$(slop $SLOP_OPTS -f "%g" 2>/dev/null)
    
    if [ -z "$geometry" ]; then
        show_notification "Captura cancelada" "Selección cancelada por el usuario"
        exit 1
    fi
    
    # Capturar la región
    if import -window root -crop "$geometry" "$FILENAME"; then
        echo "📸 Captura guardada: $FILENAME"
        copy_to_clipboard "$FILENAME"
        show_notification "Captura completada" "Guardada en:\n$(basename "$FILENAME")\nCopiada al portapapeles"
    else
        show_notification "Error" "No se pudo guardar la captura"
        exit 1
    fi
}

# Función para captura de pantalla completa
capture_full() {
    echo "🖥️  Capturando pantalla completa..."
    
    if import -window root "$FILENAME"; then
        echo "📸 Captura guardada: $FILENAME"
        copy_to_clipboard "$FILENAME"
        show_notification "Captura completada" "Pantalla completa guardada\nCopiada al portapapeles"
    else
        show_notification "Error" "No se pudo capturar pantalla completa"
        exit 1
    fi
}

# Función para captura de ventana activa
capture_window() {
    echo "🪟 Capturando ventana activa..."
    
    if ! command -v xdotool &> /dev/null; then
        show_notification "Error" "xdotool no está instalado"
        echo "⚠️  Instala xdotool para capturar ventanas:"
        echo "   sudo apt install xdotool   # Debian/Ubuntu"
        echo "   sudo pacman -S xdotool     # Arch"
        exit 1
    fi
    
    local window_id
    window_id=$(xdotool getactivewindow 2>/dev/null)
    
    if [ -z "$window_id" ]; then
        show_notification "Error" "No se pudo obtener ventana activa"
        exit 1
    fi
    
    if import -window "$window_id" "$FILENAME"; then
        echo "📸 Captura guardada: $FILENAME"
        copy_to_clipboard "$FILENAME"
        show_notification "Captura completada" "Ventana activa guardada\nCopiada al portapapeles"
    else
        show_notification "Error" "No se pudo capturar la ventana"
        exit 1
    fi
}

# Función para captura con delay
capture_delayed() {
    local delay=${1:-3}
    echo "⏱️  Captura en $delay segundos..."
    
    show_notification "Captura programada" "La captura se realizará en $delay segundos"
    
    for ((i=delay; i>0; i--)); do
        echo -ne "⏳ $i segundos...\r"
        sleep 1
    done
    echo ""
    
    capture_full
}

# Mostrar ayuda
show_help() {
    echo "Uso: $0 [OPCIÓN]"
    echo ""
    echo "Opciones:"
    echo "  region, r    Capturar región (predeterminado)"
    echo "  full, f      Capturar pantalla completa"
    echo "  window, w    Capturar ventana activa"
    echo "  delay, d [N] Capturar con delay (default: 3s)"
    echo "  help, h      Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0           # Captura región (predeterminado)"
    echo "  $0 full      # Captura pantalla completa"
    echo "  $0 delay 5   # Captura en 5 segundos"
}

# Procesar argumentos
case "${1:-region}" in
    full|f)
        capture_full
        ;;
    
    window|w)
        capture_window
        ;;
        
    delay|d)
        delay_time="${2:-3}"
        if [[ "$delay_time" =~ ^[0-9]+$ ]]; then
            capture_delayed "$delay_time"
        else
            show_notification "Error" "El delay debe ser un número"
            echo "❌ Error: El delay debe ser un número"
            exit 1
        fi
        ;;
        
    region|r|"")
        capture_region
        ;;
        
    help|h|--help)
        show_help
        ;;
        
    *)
        echo "❌ Opción desconocida: $1"
        echo "💡 Usa '$0 help' para ver las opciones disponibles"
        show_notification "Error" "Opción desconocida: $1"
        exit 1
        ;;
esac

# Mostrar ruta completa en terminal (útil para copiar)
echo "📁 Ruta completa: $FILENAME"

# Opcional: abrir con visor de imágenes
# if command -v xdg-open &> /dev/null; then
#     read -p "¿Abrir captura? (s/N): " -n 1 -r
#     echo
#     if [[ $REPLY =~ ^[Ss]$ ]]; then
#         xdg-open "$FILENAME"
#     fi
# fi