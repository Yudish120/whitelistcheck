# WhiteList VPN iOS Transport Test 0.2.1

Это нужная промежуточная версия:

```text
настоящий olcRTC
без Packet Tunnel
без Network Extension entitlement
без backend
```

## Возможности

- mobile-оптимизированный интерфейс под iPhone;
- Jitsi, WB Stream, Telemost;
- DataChannel и VP8 Channel;
- импорт YAML и `olcrtc://`;
- общий ключ в iOS Keychain;
- `Check` настоящего WebRTC peer;
- `Ping` настоящего HTTP-запроса через SOCKS5 → olcRTC → VPS;
- постоянный тестовый канал;
- отображение provider и transport;
- максимальные клиентские логи;
- liveness ping/pong ядра;
- кольцевой буфер логов 256 КБ;
- адаптивная частота обновления.

## Чего здесь нет

- системного VPN;
- `NEPacketTunnelProvider`;
- TUN → SOCKS;
- Network Extension entitlement.

Поэтому эта версия должна подписываться обычным бесплатным provisioning profile заметно проще, чем Full VPN.

Тестовый канал работает внутри приложения. Остальные приложения iPhone автоматически через него не пойдут.

## Загрузка в GitHub

Замени содержимое репозитория файлами этого проекта:

```text
.github
App
Shared
scripts
project.yml
README_RU.md
```

Папка `Frameworks` может быть пустой: workflow соберёт XCFramework сам.

Запусти:

```text
Actions
→ Build olcRTC Transport Test IPA
→ Run workflow
```

Артефакт:

```text
WhiteListTransportTest-unsigned-ipa
```

Внутри:

```text
WhiteListTransportTest-unsigned.ipa
build.log
```

## Первый тест

На VPS:

```bash
journalctl -u whitelistvpn-olcrtc -f
```

На iPhone:

1. открой «Профиль»;
2. вставь клиентский YAML или `olcrtc://`;
3. проверь `jitsi + datachannel`;
4. нажми `Check`;
5. ожидай `peers = 1` на VPS;
6. нажми `Ping`;
7. открой вкладку «Логи»;
8. запусти постоянный тестовый канал.

Текущий сервер использует:

```text
provider: jitsi
transport: datachannel
room: https://meet1.arbitr.ru/wlvpn-8fbccda03aa9cc46c60a
```

Общий ключ нужно взять из актуального `/root/whitelistvpn-client.yaml`.
Не публикуй ключ в GitHub.
