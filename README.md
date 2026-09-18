# Jarvis Glasses — M02S iPhone sideload project

This app sends the confirmed M02S AI/listening command:

- Service: `DE5BF728-D711-4E47-AF26-65E3012A5DC7`
- Write characteristic: `DE5BF72A-D711-4E47-AF26-65E3012A5DC7`
- Write type: **Without Response**
- Packet: `BC4103009052020107`

## What it does

1. First launch: scan for your M02S and select it.
2. Tap **Test Wake**. The glasses should do the same thing they did when you manually sent the packet.
3. The app exposes an iOS App Intent named **Wake Jarvis**.
4. You can assign that action to an iPhone Vocal Shortcut with the phrase **Hey Jarvis**.

## Build an IPA without a Mac

1. Make a new GitHub repository.
2. Upload **all contents of this folder**, including `.github`.
3. Open the repo's **Actions** tab.
4. Run **Build Jarvis Glasses IPA**.
5. When it finishes, download the `JarvisGlasses-unsigned-ipa` artifact.
6. Extract that artifact. Inside is `JarvisGlasses-unsigned.ipa`.
7. Use Sideloadly on Windows to sign/install the IPA with your own Apple ID.

## First setup on iPhone

1. Open **Jarvis Glasses**.
2. Allow Bluetooth.
3. Turn the M02S on.
4. Tap **Scan for M02S**.
5. Tap your glasses.
6. Wait for **M02S ready ✓**.
7. Tap **Test Wake**.

## Make "Hey Jarvis" the trigger

Go to:

`Settings > Accessibility > Vocal Shortcuts > Add Action`

Choose **Wake Jarvis** from Jarvis Glasses and train the phrase:

`Hey Jarvis`

Keep **Vocal Shortcuts** enabled.

## Important iOS behavior

- Background Bluetooth support is enabled in `Info.plist` with `bluetooth-central`.
- iOS can still restrict background BLE in some situations.
- If you force-quit Jarvis Glasses, reopen it before expecting background behavior.
- Keep the glasses on and in BLE range.

## Sideloading note

Free Apple developer signing normally expires after 7 days, so use Sideloadly's refresh feature or reinstall/resign when needed.
