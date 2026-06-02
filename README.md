# 🚀 nfqws2: снятие ограничения 15 портов

Автоматическое разделение одиночных портов и диапазонов для iptables фильтрации

> ✅ Протестировано на Keenetic NC-1812 | Ядро 4.9-ndm-5 | nfqws2 Release v1.1.5
> 
‼️ ЭТО МОЖЕТ НЕ РАБОТАТЬ НА ОТЛИЧНЫХ ОТ aarch64 АРХИТЕКТУРАХ И ДРУГИХ ВЕРСИЯХ NFQWS2‼️

‼️ ИСПОЛЬЗУЙТЕ ЭТО ЕСЛИ ПОНИМАЕТЕ КАК ВЕРНУТЬ ВСЁ "ВЗАД"‼️

---

## 📋 Резюме выполненной работы

### 1. Анализ проблемы
- Выявлено ограничение в **15 элементов** для `-m multiport` в iptables
- В конфигурации `nfqws2` используются переменные `TCP_PORTS` и `UDP_PORTS`
- При превышении лимита возникает ошибка добавления правил

### 2. Диагностика окружения
- Обнаружен модуль ядра `ip_set_bitmap_port.ko` в системе Keenetic
- Модуль успешно загружен через `insmod`
- Подтверждена работа `bitmap:port` в ipset

### 3. Разработанное решение
- Функция `split_ports()` — разделяет одиночные порты и диапазоны
- Функция `create_bitmap_ipset()` — создаёт ipset типа `bitmap:port`
- Модифицирована `ensure_ipsets()` — автоматический выбор метода
- Обновлена `_firewall_start()` — добавлены правила для обоих методов

### 4. Финальная архитектура

| Тип данных | Пример | Метод фильтрации | Ограничение |
|------------|--------|------------------|-------------|
| Одиночный порт | `443` | `bitmap:port` (ipset) | ❌ Нет (до 65535) |
| Диапазон портов | `590:600` | `-m multiport` | ⚠️ 7 диапазонов |

### 5. Результаты тестирования

| Параметр | Значение | Статус |
|----------|----------|--------|
| TCP порты (одиночные) | `80,443,1984,2053,2083,2087,2096,5222,8443` | ✅ bitmap:port |
| UDP порты (одиночные) | `443,1400,5349` | ✅ bitmap:port |
| UDP диапазоны | `590:600,3478:3481,19294:19344,49152:65535` | ✅ multiport |

### 6. Достигнутые преимущества

- ✅ **Единый конфиг** — только `TCP_PORTS`/`UDP_PORTS`
- ✅ **Автоматическое определение** типа порта (одиночный/диапазон)
- ✅ **Снято ограничение** 15 элементов для одиночных портов
- ✅ **Диапазоны** работают через штатный `multiport`
- ✅ **Быстрый запуск** — диапазоны не разворачиваются в цикле
- ✅ **Полная обратная совместимость**

---

## 📥 БЫСТРЫЙ СТАРТ

### 1. Сделайте резервные копии текущих файлов
```bash
# Остановить сервис nfqws2
/opt/etc/init.d/S51nfqws2 stop

# Сделать из основных файлов - резервные копии
mv /opt/etc/init.d/S51nfqws2 /opt/etc/init.d/S51nfqws2.bak
mv /opt/etc/ndm/netfilter.d/100-nfqws2.sh /opt/etc/ndm/netfilter.d/100-nfqws2.sh.bak
```
### 2. Скачайте готовые файлы из этого репозитория сразу в нужные директории
```bash
wget -P /opt/etc/ndm/netfilter.d https://github.com/Fat32al1st/nfqws2-keenetic-mod-unlimited-tcp-udp-single-ports/blob/caaf451d5004a4cd98a6a4b76f7b57a7f5491ce8/100-nfqws2.sh
wget -P /opt/etc/init.d https://github.com/Fat32al1st/nfqws2-keenetic-mod-unlimited-tcp-udp-single-ports/blob/caaf451d5004a4cd98a6a4b76f7b57a7f5491ce8/S51nfqws2
# Выдать файлу S51nfqws права на исполнение
chmod +x /opt/etc/init.d/S51nfqws2
```
### 3. Отредактировать /opt/etc/nfqws2/nfqws2.conf чтобы UDP_PORTS и TCP_PORTS точно были в кавычках ""
```bash
sed -i -e 's/^\(TCP_PORTS=\|UDP_PORTS=\)[[:space:]]*\([^"'"'"'].*\)$/\1"\2"/' /opt/etc/nfqws2/nfqws2.conf
```
### 3. Запуск сервиса nfqws2
```bash
/opt/etc/init.d/S51nfqws2 start
```

---

## 📥 РУЧНАЯ ИНТЕГРАЦИЯ

## 🔧 Действия для интеграции в обычную версию

### 📋 Предварительные требования

- Наличие `ipset` с поддержкой `bitmap:port`
- Модуль ядра `ip_set_bitmap_port.ko`

### 📝 Пошаговая инструкция

#### Шаг 1: Проверка поддержки bitmap:port

```bash
# Проверить доступные типы ipset
ipset help 2>&1 | grep bitmap:port

# Найти модуль
find /lib/modules -name "ip_set_bitmap_port.ko" 2>/dev/null

# Загрузить модуль (если найден)
insmod /path/to/ip_set_bitmap_port.ko
```
Шаг 2: Добавить функцию split_ports()
В файл /opt/etc/init.d/S51nfqws2 добавить:

```bash
split_ports() {
  local ports_str="$1"
  local single_ports=""
  local ranges=""
  
  OIFS=$IFS; IFS=','; for item in $ports_str; do
    if echo "$item" | grep -q ':'; then
      ranges="${ranges:+$ranges,}$item"
    else
      single_ports="${single_ports:+$single_ports,}$item"
    fi
  done; IFS=$OIFS
  
  echo "$single_ports"
  echo "$ranges"
}
```
Шаг 3: Добавить функцию create_bitmap_ipset()
```bash
create_bitmap_ipset() {
  local name="$1"
  local ports="$2"
  
  [ -z "$ports" ] && return 1
  
  ipset create "$name" bitmap:port range 0-65535 2>/dev/null
  ipset flush "$name"
  
  OIFS=$IFS; IFS=','; for port in $ports; do
    ipset add "$name" "$port"
  done; IFS=$OIFS
  
  return 0
}
```
Шаг 4: Модифицировать ensure_ipsets()
Заменить существующую функцию:
```bash
ensure_ipsets() {
  if ! command -v ipset >/dev/null 2>&1; then
    return 1
  fi
  
  # Разделяем порты на одиночные и диапазоны
  TCP_SINGLE=$(split_ports "$TCP_PORTS" | head -1)
  TCP_RANGES=$(split_ports "$TCP_PORTS" | tail -1)
  UDP_SINGLE=$(split_ports "$UDP_PORTS" | head -1)
  UDP_RANGES=$(split_ports "$UDP_PORTS" | tail -1)
  
  # Создаём bitmap ipset для одиночных портов
  if [ -n "$TCP_SINGLE" ]; then
    create_bitmap_ipset "nfqws_ports_tcp" "$TCP_SINGLE"
  fi
  
  if [ -n "$UDP_SINGLE" ]; then
    create_bitmap_ipset "nfqws_ports_udp" "$UDP_SINGLE"
  fi
  
  # Экспортируем диапазоны для использования в firewall правилах
  export TCP_RANGES UDP_RANGES
}
```
Шаг 5: Обновить _firewall_start() для POSTROUTING
Найти блок с UDP правилами и заменить:
```bash
# UDP out (исходящий трафик)
if [ -n "$UDP_SINGLE" ]; then
    $CMD -w -t mangle -A $IPT_GROUP_POST -o $IFACE $CONN_CHECK -p udp \
        -m set --match-set nfqws_ports_udp dst $CB_ORIG --connbytes 1:$MAX_PKT_OUT $JNFQ
fi
if [ -n "$UDP_RANGES" ]; then
    $CMD -w -t mangle -A $IPT_GROUP_POST -o $IFACE $CONN_CHECK -p udp \
        -m multiport --dports $UDP_RANGES $CB_ORIG --connbytes 1:$MAX_PKT_OUT $JNFQ
fi

# TCP out (исходящий трафик)
if [ -n "$TCP_SINGLE" ]; then
    $CMD -w -t mangle -A $IPT_GROUP_POST -o $IFACE $CONN_CHECK -p tcp \
        -m set --match-set nfqws_ports_tcp dst $CB_ORIG --connbytes 1:$MAX_PKT_OUT $JNFQ
    $CMD -w -t mangle -A $IPT_GROUP_POST -o $IFACE $CONN_CHECK -p tcp \
        -m set --match-set nfqws_ports_tcp dst --tcp-flags fin fin $JNFQ
    $CMD -w -t mangle -A $IPT_GROUP_POST -o $IFACE $CONN_CHECK -p tcp \
        -m set --match-set nfqws_ports_tcp dst --tcp-flags rst rst $JNFQ
fi
if [ -n "$TCP_RANGES" ]; then
    $CMD -w -t mangle -A $IPT_GROUP_POST -o $IFACE $CONN_CHECK -p tcp \
        -m multiport --dports $TCP_RANGES $CB_ORIG --connbytes 1:$MAX_PKT_OUT $JNFQ
    $CMD -w -t mangle -A $IPT_GROUP_POST -o $IFACE $CONN_CHECK -p tcp \
        -m multiport --dports $TCP_RANGES --tcp-flags fin fin $JNFQ
    $CMD -w -t mangle -A $IPT_GROUP_POST -o $IFACE $CONN_CHECK -p tcp \
        -m multiport --dports $TCP_RANGES --tcp-flags rst rst $JNFQ
fi
```
Шаг 6: Обновить _firewall_start() для PREROUTING
Аналогично для входящего трафика (заменить --dports на --sports):

```bash
# UDP in (входящий/ответный трафик)
if [ -n "$UDP_SINGLE" ]; then
    $CMD -w -t mangle -A $IPT_GROUP_PRE -i $IFACE $CONN_CHECK -p udp \
        -m set --match-set nfqws_ports_udp dst $CB_REPLY --connbytes 1:$MAX_PKT_IN $JNFQ
fi
if [ -n "$UDP_RANGES" ]; then
    $CMD -w -t mangle -A $IPT_GROUP_PRE -i $IFACE $CONN_CHECK -p udp \
        -m multiport --sports $UDP_RANGES $CB_REPLY --connbytes 1:$MAX_PKT_IN $JNFQ
fi

# TCP in (входящий/ответный трафик)
if [ -n "$TCP_SINGLE" ]; then
    $CMD -w -t mangle -A $IPT_GROUP_PRE -i $IFACE $CONN_CHECK -p tcp \
        -m set --match-set nfqws_ports_tcp dst $CB_REPLY --connbytes 1:$MAX_PKT_IN $JNFQ
    $CMD -w -t mangle -A $IPT_GROUP_PRE -i $IFACE $CONN_CHECK -p tcp \
        -m set --match-set nfqws_ports_tcp dst --tcp-flags syn,ack syn,ack $JNFQ
    $CMD -w -t mangle -A $IPT_GROUP_PRE -i $IFACE $CONN_CHECK -p tcp \
        -m set --match-set nfqws_ports_tcp dst --tcp-flags fin fin $JNFQ
    $CMD -w -t mangle -A $IPT_GROUP_PRE -i $IFACE $CONN_CHECK -p tcp \
        -m set --match-set nfqws_ports_tcp dst --tcp-flags rst rst $JNFQ
fi
if [ -n "$TCP_RANGES" ]; then
    $CMD -w -t mangle -A $IPT_GROUP_PRE -i $IFACE $CONN_CHECK -p tcp \
        -m multiport --sports $TCP_RANGES $CB_REPLY --connbytes 1:$MAX_PKT_IN $JNFQ
    $CMD -w -t mangle -A $IPT_GROUP_PRE -i $IFACE $CONN_CHECK -p tcp \
        -m multiport --sports $TCP_RANGES --tcp-flags syn,ack syn,ack $JNFQ
    $CMD -w -t mangle -A $IPT_GROUP_PRE -i $IFACE $CONN_CHECK -p tcp \
        -m multiport --sports $TCP_RANGES --tcp-flags fin fin $JNFQ
    $CMD -w -t mangle -A $IPT_GROUP_PRE -i $IFACE $CONN_CHECK -p tcp \
        -m multiport --sports $TCP_RANGES --tcp-flags rst rst $JNFQ
fi
```

Шаг 7: Добавить загрузку модуля ядра
В функцию kernel_modules() добавить:

```bash
# Load ip_set_bitmap_port module for bitmap:port support
if [ -z "$(lsmod 2>/dev/null | grep "ip_set_bitmap_port ")" ]; then
  bitmap_port_mod_path=$(find "/lib/modules/$KERNEL" -name "ip_set_bitmap_port.ko*" | head -n 1)
  if [ -n "$bitmap_port_mod_path" ]; then
    insmod "$bitmap_port_mod_path" &> /dev/null
    if [ -n "$(lsmod 2>/dev/null | grep "ip_set_bitmap_port ")" ]; then
      echo "ip_set_bitmap_port.ko loaded"
    fi
  fi
fi
```
Шаг 8: Упростить /opt/etc/ndm/netfilter.d/100-nfqws2.sh
```bash
#!/bin/sh

PIDFILE="/opt/var/run/nfqws2.pid"

if [ ! -f "$PIDFILE" ] || ! kill -0 $(cat "$PIDFILE") 2>/dev/null; then
  exit
fi

[ "$table" != "mangle" ] && [ "$table" != "nat" ] && exit
/opt/etc/init.d/S51nfqws2 firewall_"$type"
```
Шаг 9: Обновить конфигурацию
В файле /opt/etc/nfqws2/nfqws2.conf:

# Пример правильной конфигурации !!! Двойные кавычки ОБЯЗАТЕЛЬНО
```
TCP_PORTS="80,443,1984,2053,2083,2087,2096,5222,8443"
UDP_PORTS="443,590:600,1400,3478:3481,5349,19294:19344,49152:65535"
```

Шаг 10: Перезапустить и проверить
```bash
# Перезапуск сервиса
/opt/etc/init.d/S51nfqws2 restart

# Проверка правил iptables
iptables-save | grep -E "set.*match-set|multiport"

# Проверка ipset
ipset list nfqws_ports_tcp
ipset list nfqws_ports_udp
```
# Проверка статуса
```
/opt/etc/init.d/S51nfqws2 status
```
📝 Пример конфигурации nfqws2.conf
```
# TCP ports - одиночные порты и диапазоны
TCP_PORTS="80,443,1984,2053,2083,2087,2096,5222,8443"

# UDP ports - одиночные порты и диапазоны
UDP_PORTS="443,590:600,1400,3478:3481,5349,19294:19344,49152:65535"
```
⚠️ Важно: Все значения должны быть в кавычках.

📊 Проверка работоспособности
```bash
# Просмотр всех правил nfqws2
iptables-save | grep nfqws

# Просмотр счетчиков трафика
iptables -t mangle -L nfqws_post -nv
iptables -t mangle -L nfqws_pre -nv

# Просмотр ipset
ipset list nfqws_ports_tcp
ipset list nfqws_ports_udp

# Проверка конкретного порта
ipset test nfqws_ports_udp 443
```
📌 Заключение
Модификация позволяет:

Использовать неограниченное количество одиночных портов через bitmap:port

Сохранить поддержку диапазонов портов через multiport

Не менять привычный формат конфигурации

Сохранить полную обратную совместимость

Протестировано на: Keenetic NC-1812, ядро 4.9-ndm-5, nfqws2 Release v1.1.5

🔗 Ссылки

Официальный репозиторий [nfqws2-keenetic](https://github.com/nfqws/nfqws2-keenetic)
Исходный код [zapret2](https://github.com/bol-van/zapret2)

Автор модификации: Fat32alist (с использованием DeepSeek) | *Дата: 2026-06-02*
