# The Poorest Man's PoE Adapter (SR9700 Driver for Thingino)

**Disclaimer: This is a terrible idea.** Going through this much trouble to use what is objectively the worst USB ethernet adapter on the market makes no sense. If you are going to build a custom PoE adapter for Thingino, you *should* use a supported adapter like the Amazon Basics USB 2.0 (ASIX/Realtek based), which costs $5 and works natively.

But if you are stubborn, cheap, or just enjoy pain... let's get into it.

## My Story

I wanted to build a PoE solution for a stack of refurbished Wyze Cam V3s I got for ~$17/each. Factory PoE adapters (which provide a USB OTG ethernet adapter and PoE power to both the ethernet adapter and the host camera) are easily available. But, they cost more than I paid for the cameras, so clearly I'm not going to use them.

**My Bill of Materials:**
* **Ethernet Adapter:** The cheapest USB ethernet adapter I could find on AliExpress ($1.12 per item), which turned out to be an SR9700-based adapter. (Net Cost: $0.00 after refund because they lied about USB 2.0 support, it's actually a USB 1.1 device).
* **PoE Splitter:** Waterproof generic 12V output module ($1.71).
* **Buck Converter:** Mini DC-DC step down, 12V->5V ($0.46).
* **Junk:** Scrap twisted pair wires, silicon tape, heat shrink, project boxes.
* **Total cost per unit:**  $2.17 plus a lot of my time.

**The Hardware Hack:**
1.  **Set Voltage:** Ensure your buck converter is outputting exactly 5V. Solder jumper pads if necessary (this step will be module specific).
2.  **Split Power:** Take the 12V output from the PoE splitter and solder it to the **Input** of the buck converter.
3.  **Injector Surgery:** Crack open the cheap USB Ethernet adapter (usually held together with a sticker). Solder the **5V Output** from the buck converter to the VCC/GND pads on the adapter (red/black generally), which will be shared with the host device.
4.  **Assembly:** Wrap it all in heat shrink/tape/project box. Plug the Ethernet side into a PoE switch and confirm the link is active. Then you can plug the USB side into the camera.

## The Software Nightmare

If you plug this into a modern Linux machine, it might work. If you plug it into Thingino (Linux 3.10), it fails.

The `sr9700` driver didn't exist in Linux 3.10. It was added in 3.18. However, backporting the 3.18 driver fails because "modern" "SR9700" chips (often labeled SR9700B or SR9702) have a hardware quirk where they ignore command writes unless sent as specific "Single Register" USB packets. Plus, the chips may advertise a different device ID to account for the fact that they also have a USB flash memory chip with sketchy windows drivers.

This was only fixed in mainline Linux 6.19 in 2025, so we're not going to try to compile the fixed driver from Linux 6.19 in the 3.10 build.

(These are the fixes that will get one of these AliExpress SR9700B chips working)
* [Commit 1: Fix SR_NCR writes](https://github.com/torvalds/linux/commit/fa0b198be1c6775bc7804731a43be5d899d19e7a)
* [Commit 2: Fix PHY initialization](https://github.com/torvalds/linux/commit/bf4172bd870c3a34d3065cbb39192c22cbd7b18d)

This repo contains a backported version of the driver that runs on the Thingino 3.10 kernel but includes the recent fixes required to make these cheap chips actually work.

---

## Installation Method 1: The Easy Way (Pre-compiled)

If you just want it to work, use the pre-compiled kernel module.

1.  Connect your Thingino camera to Wi-Fi so it has internet access.
2.  SSH into the camera.
3.  Run this command:

```bash
curl -L https://raw.githubusercontent.com/lansing/thingino-sr9700/main/scripts/install-ko.sh | bash
```

This will download the driver, install it, and set it to load on boot.

## Installation Method 2: Build from Source

If you are building your own Thingino firmware and want this driver baked into the image, follow these steps.

I do all of this inside the docker container supplied in the `thingino-firmware` repo via:

```
./docker-build.sh sh
```

But you could do it directly in the host machine if you have a known working build setup.

1.  **Prepare the Build Environment:**
    Ensure you have already built the firmware at least once (or downloaded the Buildroot cache) so the Linux kernel source tree is present in the `output-stable` directory.

2.  **Patch the Source Tree:**
    From the root of your `thingino-firmware` directory on your build host, run this command to download the source files and inject them into the kernel tree:

    ```bash
    curl -L https://raw.githubusercontent.com/lansing/thingino-sr9700/main/scripts/patch-tree.sh | bash
    ```

3.  **Configure the Kernel:**

    Open the Thingino menu configuration tool:
    ```bash
    ./user-menu.sh
    ```
    Navigate to:
    * **Main Menu**
    * **Linux Kernel Configuration**

4.  **Enable the Driver:**
    In the Linux Kernel Configuration menu, navigate to:
    * **Device Drivers**
    * **Network device support**
    * **USB Network Adapters**

    Scroll down until you find **"CoreChip SR9700 USB 1.1 Ethernet"**.
    * Press `Y` to include it directly in the kernel (recommended).
    * Or press `M` to build it as a module.

5.  **Save and Exit:**
    Exit to the main menu, saving your changes when prompted.

6.  **Rebuild the Firmware:**
    Force a rebuild of the Linux kernel and generate the new firmware image:
    **Main Menu**
    **make** or **make fast**

7.  **Flash and Enjoy:**
    Flash the new firmware image to your camera using your preferred method. The `sr9700` driver will now initialize automatically on boot, detect your composite device, and negotiate the link correctly.


