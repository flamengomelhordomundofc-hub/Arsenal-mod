#!/usr/bin/env bash
set -e
echo "=========================================================="
echo "   ARSENAL 3D v2.0 (REALISTA) - COMPILADOR 1.20.1 FORGE   "
echo "=========================================================="

IS_TERMUX=0
if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ]; then IS_TERMUX=1; fi

if [ "$IS_TERMUX" -eq 1 ]; then
    echo "[1/5] Instalando Java 17 no Termux..."
    pkg update -y >/dev/null 2>&1 || true
    pkg install -y openjdk-17 wget unzip >/dev/null
    export JAVA_HOME="${PREFIX}/lib/jvm/java-17-openjdk"
    [ -d "$JAVA_HOME" ] || JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
    export PATH="$JAVA_HOME/bin:$PATH"
    HEAP="-Xmx1536m"
else
    echo "[1/5] Verificando Java 17..."
    if ! command -v java >/dev/null 2>&1; then
        sudo apt-get update -y && sudo apt-get install -y openjdk-17-jdk wget unzip
    fi
    HEAP="-Xmx3G"
fi

GDIR="$HOME/.gradle-8.1.1"
GBIN="$GDIR/gradle-8.1.1/bin/gradle"
if [ ! -x "$GBIN" ]; then
    echo "[2/5] Baixando Gradle 8.1.1..."
    mkdir -p "$GDIR"
    wget -q -O "$GDIR/g.zip" "https://services.gradle.org/distributions/gradle-8.1.1-bin.zip"
    unzip -q -o "$GDIR/g.zip" -d "$GDIR" && rm -f "$GDIR/g.zip"
else
    echo "[2/5] Gradle 8.1.1 ja instalado!"
fi

BASE_DIR="$PWD"
W="$PWD/arsenalmod_v2"
rm -rf "$W" && mkdir -p "$W" && cd "$W"
mkdir -p src/main/java/com/arsenalmod/{item,registry,entity,network,client}
mkdir -p src/main/resources/META-INF src/main/resources/assets/arsenalmod/{lang,models/item,textures/item,textures/entity}

echo "[3/5] Gerando codigo completo do mod v2.0..."

cat << EOF > gradle.properties
org.gradle.jvmargs=${HEAP}
org.gradle.daemon=false
org.gradle.parallel=false
EOF

cat << 'ARSENAL_V2_EOF' > "build.gradle"
plugins {
    id 'java'
    id 'net.minecraftforge.gradle' version '6.0.24'
}
group = 'com.arsenalmod'
version = '2.0.0'
base { archivesName = 'arsenalmod' }
java.toolchain.languageVersion = JavaLanguageVersion.of(17)
minecraft { mappings channel: 'official', version: '1.20.1' }
dependencies { minecraft 'net.minecraftforge:forge:1.20.1-47.2.0' }
tasks.withType(JavaCompile).configureEach { options.encoding = 'UTF-8' }
tasks.named('jar', Jar).configure {
    manifest {
        attributes([
            'Specification-Title'    : 'arsenalmod',
            'Specification-Vendor'   : 'arsenalmod',
            'Specification-Version'  : '2',
            'Implementation-Title'   : project.name,
            'Implementation-Version' : project.version,
            'Implementation-Vendor'  : 'arsenalmod'
        ])
    }
    finalizedBy 'reobfJar'
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "settings.gradle"
pluginManagement {
    repositories {
        gradlePluginPortal()
        maven {
            name = 'MinecraftForge'
            url = 'https://maven.minecraftforge.net/'
        }
    }
}
rootProject.name = 'arsenalmod'
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/ArsenalMod.java"
package com.arsenalmod;

import com.arsenalmod.network.ModNetwork;
import com.arsenalmod.registry.*;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.event.lifecycle.FMLCommonSetupEvent;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;

@Mod(ArsenalMod.MODID)
public class ArsenalMod {
    public static final String MODID = "arsenalmod";
    public ArsenalMod() {
        IEventBus bus = FMLJavaModLoadingContext.get().getModEventBus();
        ModItems.ITEMS.register(bus);
        ModEntities.ENTITIES.register(bus);
        ModCreativeTabs.TABS.register(bus);
        bus.addListener((FMLCommonSetupEvent e) -> e.enqueueWork(ModNetwork::register));
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/client/BulletRenderer.java"
package com.arsenalmod.client;

import com.arsenalmod.entity.BulletEntity;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;

public class BulletRenderer extends EntityRenderer<BulletEntity> {
    public BulletRenderer(EntityRendererProvider.Context ctx) {
        super(ctx);
    }

    @Override
    public void render(BulletEntity entity, float entityYaw, float partialTick,
                       PoseStack ps, MultiBufferSource buffer, int light) {
        ps.pushPose();
        float yaw = Mth.lerp(partialTick, entity.yRotO, entity.getYRot());
        float pitch = Mth.lerp(partialTick, entity.xRotO, entity.getXRot());
        ps.mulPose(Axis.YP.rotationDegrees(yaw));
        ps.mulPose(Axis.XP.rotationDegrees(-pitch));
        GunModelGeometry.renderBullet3D(ps, buffer);
        ps.popPose();
        super.render(entity, entityYaw, partialTick, ps, buffer, light);
    }

    @Override
    public ResourceLocation getTextureLocation(BulletEntity entity) {
        return GunModelGeometry.ATLAS;
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/client/ClientEvents.java"
package com.arsenalmod.client;

import com.arsenalmod.ArsenalMod;
import com.arsenalmod.item.GunItem;
import com.arsenalmod.item.GunType;
import com.arsenalmod.network.C2SReloadPacket;
import com.arsenalmod.network.C2SShootPacket;
import com.arsenalmod.network.ModNetwork;
import com.arsenalmod.registry.ModItems;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.util.Mth;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.InputEvent;
import net.minecraftforge.client.event.RenderGuiOverlayEvent;
import net.minecraftforge.client.event.RenderLevelStageEvent;
import net.minecraftforge.client.event.ViewportEvent;
import net.minecraftforge.client.gui.overlay.VanillaGuiOverlay;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = ArsenalMod.MODID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
public class ClientEvents {
    private static boolean wasAttackDown = false;
    private static long nextLocalShotTick = 0L;

    @SubscribeEvent
    public static void onRenderTick(TickEvent.RenderTickEvent event) {
        if (event.phase == TickEvent.Phase.START) {
            GunAnimationEngine.updateFrame();
        }
    }

    @SubscribeEvent
    public static void onRenderLevelStage(RenderLevelStageEvent event) {
        if (event.getStage() == RenderLevelStageEvent.Stage.AFTER_PARTICLES) {
            WorldEffectsRenderer.render(event.getPoseStack(), event.getCamera(), event.getPartialTick());
        }
    }

    @SubscribeEvent
    public static void onClientTick(TickEvent.ClientTickEvent event) {
        if (event.phase != TickEvent.Phase.END) return;
        Minecraft mc = Minecraft.getInstance();
        LocalPlayer player = mc.player;
        if (player == null || mc.screen != null) {
            GunAnimationEngine.isAiming = false;
            wasAttackDown = false;
            return;
        }

        ItemStack stack = player.getMainHandItem();
        if (!(stack.getItem() instanceof GunItem gun)) {
            GunAnimationEngine.isAiming = false;
            wasAttackDown = false;
            return;
        }

        GunType type = gun.getType();
        long now = player.level().getGameTime();

        // ADS (Right Click)
        GunAnimationEngine.isAiming = mc.options.keyUse.isDown();

        // Reload (R key)
        while (ModKeyBindings.RELOAD_KEY.consumeClick()) {
            ModNetwork.INSTANCE.sendToServer(new C2SReloadPacket());
        }

        // Fire (Left Click)
        boolean attackDown = mc.options.keyAttack.isDown();
        boolean triggerPressed = type.fullAuto ? attackDown : (attackDown && !wasAttackDown);
        wasAttackDown = attackDown;

        if (triggerPressed && !gun.isReloading(stack, now) && now >= nextLocalShotTick) {
            int ammo = gun.getAmmo(stack);
            if (ammo > 0) {
                nextLocalShotTick = now + type.fireCooldown;
                GunAnimationEngine.onLocalShot(type, player);
                ModNetwork.INSTANCE.sendToServer(new C2SShootPacket(GunAnimationEngine.isAiming));
            } else {
                nextLocalShotTick = now + 10L;
                ModNetwork.INSTANCE.sendToServer(new C2SReloadPacket());
            }
        }
    }

    @SubscribeEvent
    public static void onClickInput(InputEvent.InteractionKeyMappingTriggered event) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null) return;
        if (mc.player.getMainHandItem().getItem() instanceof GunItem) {
            if (event.isAttack() || event.isUseItem()) {
                event.setCanceled(true);
                event.setSwingHand(false);
            }
        }
    }

    @SubscribeEvent
    public static void onComputeFov(ViewportEvent.ComputeFov event) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null) return;
        ItemStack stack = mc.player.getMainHandItem();
        if (!(stack.getItem() instanceof GunItem gun)) return;
        if (GunAnimationEngine.ads > 0.001F) {
            double baseFov = event.getFOV();
            event.setFOV(Mth.lerp(GunAnimationEngine.ads, baseFov, baseFov * gun.getType().adsFov));
        }
    }

    @SubscribeEvent
    public static void onRenderGuiOverlayPre(RenderGuiOverlayEvent.Pre event) {
        if (!event.getOverlay().id().equals(VanillaGuiOverlay.CROSSHAIR.id())) return;
        Minecraft mc = Minecraft.getInstance();
        if (mc.player != null && mc.player.getMainHandItem().getItem() instanceof GunItem) {
            event.setCanceled(true);
        }
    }

    @SubscribeEvent
    public static void onRenderGuiOverlayPost(RenderGuiOverlayEvent.Post event) {
        if (!event.getOverlay().id().equals(VanillaGuiOverlay.HOTBAR.id())) return;
        Minecraft mc = Minecraft.getInstance();
        LocalPlayer player = mc.player;
        if (player == null || mc.options.hideGui) return;

        GuiGraphics gg = event.getGuiGraphics();
        int w = event.getWindow().getGuiScaledWidth();
        int h = event.getWindow().getGuiScaledHeight();

        ItemStack stack = player.getMainHandItem();
        if (stack.getItem() instanceof GunItem gun) {
            GunType type = gun.getType();
            if (type.isSniper && GunAnimationEngine.ads > 0.85F) {
                renderSniperScope(gg, w, h);
            } else if (GunAnimationEngine.ads < 0.65F) {
                renderCrosshair(gg, w, h, type);
            }
            renderWeaponHud(gg, mc, player, stack, gun, w, h);
        }

        // FPS Hitmarker (renders even right after switching/scoping)
        if (GunAnimationEngine.hitTimer > 0.0F) {
            renderHitmarker(gg, w, h);
        }
    }

    private static void renderHitmarker(GuiGraphics gg, int w, int h) {
        int cx = w / 2;
        int cy = h / 2;
        float t = Mth.clamp(GunAnimationEngine.hitTimer / 0.26F, 0.0F, 1.0F);
        int alpha = (int) (t * 255.0F) & 0xFF;
        int rgb = GunAnimationEngine.hitKill ? 0xFF2222 : (GunAnimationEngine.hitHead ? 0xFFD700 : 0xFFFFFF);
        int col = (alpha << 24) | rgb;
        int start = GunAnimationEngine.hitHead ? 4 : 3;
        int end = GunAnimationEngine.hitKill ? 11 : (GunAnimationEngine.hitHead ? 10 : 8);

        for (int i = start; i <= end; i++) {
            gg.fill(cx - i, cy - i, cx - i + 2, cy - i + 2, col);
            gg.fill(cx + i - 1, cy - i, cx + i + 1, cy - i + 2, col);
            gg.fill(cx - i, cy + i - 1, cx - i + 2, cy + i + 1, col);
            gg.fill(cx + i - 1, cy + i - 1, cx + i + 1, cy + i + 1, col);
        }
    }

    private static void renderSniperScope(GuiGraphics gg, int w, int h) {
        int cx = w / 2;
        int cy = h / 2;
        int radius = Math.min(w, h) * 44 / 100;
        int black = 0xFF000000;

        gg.fill(0, 0, w, cy - radius, black);
        gg.fill(0, cy + radius, w, h, black);

        for (int dy = -radius; dy < radius; dy += 2) {
            double norm = dy / (double) radius;
            int halfSpan = (int) (radius * Math.sqrt(Math.max(0.0, 1.0 - norm * norm)));
            int y0 = cy + dy;
            int y1 = Math.min(cy + radius, y0 + 2);
            gg.fill(0, y0, cx - halfSpan, y1, black);
            gg.fill(cx + halfSpan, y0, w, y1, black);
        }

        int lineColor = 0xD8000000;
        gg.fill(cx - radius, cy, cx + radius, cy + 1, lineColor);
        gg.fill(cx, cy - radius, cx + 1, cy + radius, lineColor);

        int postOffset = radius / 2;
        gg.fill(cx - radius, cy - 1, cx - postOffset, cy + 2, black);
        gg.fill(cx + postOffset, cy - 1, cx + radius, cy + 2, black);
        gg.fill(cx - 1, cy + postOffset, cx + 2, cy + radius, black);

        int step = Math.max(8, radius / 9);
        for (int i = 1; i <= 4; i++) {
            int off = i * step;
            gg.fill(cx - off, cy - 3, cx - off + 1, cy + 4, lineColor);
            gg.fill(cx + off, cy - 3, cx + off + 1, cy + 4, lineColor);
            gg.fill(cx - 3, cy - off, cx + 4, cy - off + 1, lineColor);
            gg.fill(cx - 3, cy + off, cx + 4, cy + off + 1, lineColor);
        }

        gg.fill(cx - 1, cy - 1, cx + 2, cy + 2, 0xFFFF2222);
    }

    private static void renderCrosshair(GuiGraphics gg, int w, int h, GunType type) {
        int cx = w / 2;
        int cy = h / 2;
        int gap = (int) (4 + type.spread * 1.4F + Math.max(0.0F, GunAnimationEngine.recZ) * 40.0F);
        int len = 6;
        int col = 0xE6FFFFFF;
        int shadow = 0x99000000;

        gg.fill(cx - gap - len - 1, cy - 1, cx - gap + 1, cy + 2, shadow);
        gg.fill(cx + gap, cy - 1, cx + gap + len + 2, cy + 2, shadow);
        gg.fill(cx - 1, cy - gap - len - 1, cx + 2, cy - gap + 1, shadow);
        gg.fill(cx - 1, cy + gap, cx + 2, cy + gap + len + 2, shadow);

        gg.fill(cx - gap - len, cy, cx - gap, cy + 1, col);
        gg.fill(cx + gap + 1, cy, cx + gap + len + 1, cy + 1, col);
        gg.fill(cx, cy - gap - len, cx + 1, cy - gap, col);
        gg.fill(cx, cy + gap + 1, cx + 1, cy + gap + len + 1, col);
        gg.fill(cx, cy, cx + 1, cy + 1, 0xFFFF4444);
    }

    private static void renderWeaponHud(GuiGraphics gg, Minecraft mc, LocalPlayer player,
                                        ItemStack stack, GunItem gun, int w, int h) {
        GunType type = gun.getType();
        long now = player.level().getGameTime();
        int ammo = gun.getAmmo(stack);
        boolean reloading = gun.isReloading(stack, now);

        int boxW = 134;
        int boxH = 40;
        int x = w - boxW - 10;
        int y = h - boxH - 10;

        gg.fill(x, y, x + boxW, y + boxH, 0xB40E1318);
        gg.fill(x, y, x + boxW, y + 1, 0xFF475569);
        gg.fill(x, y + boxH - 1, x + boxW, y + boxH, 0xFF475569);
        gg.fill(x, y, x + 2, y + boxH, 0xFFEAB308);

        String mode = type.isRocket ? "HEAT" : (type.fullAuto ? "AUTO" : "SEMI");
        gg.drawString(mc.font, type.displayName, x + 7, y + 5, 0xFFF8FAFC, true);
        gg.drawString(mc.font, mode, x + boxW - mc.font.width(mode) - 6, y + 5, 0xFF94A3B8, false);

        if (reloading) {
            float prog = gun.getReloadProgress(stack, now, mc.getFrameTime());
            gg.drawString(mc.font, "RECARREGANDO...", x + 7, y + 17, 0xFFFACC15, true);
            int barX = x + 7;
            int barY = y + 30;
            int barW = boxW - 14;
            gg.fill(barX, barY, barX + barW, barY + 4, 0xFF1E293B);
            gg.fill(barX, barY, barX + (int) (barW * prog), barY + 4, 0xFFEAB308);
        } else {
            int ammoColor = (ammo == 0) ? 0xFFEF4444 : (ammo <= Math.max(1, type.maxAmmo / 4) ? 0xFFF59E0B : 0xFFFFFFFF);
            String ammoTxt = ammo + " / " + type.maxAmmo;
            gg.drawString(mc.font, ammoTxt, x + 7, y + 20, ammoColor, true);

            String reserveTxt;
            if (player.isCreative()) {
                reserveTxt = "INF";
            } else {
                Item ammoItem = ModItems.getAmmoItem(type.ammoKind);
                int packs = 0;
                for (ItemStack inv : player.getInventory().items) {
                    if (inv.is(ammoItem)) packs += inv.getCount();
                }
                reserveTxt = "RES: " + (packs * type.roundsPerAmmoItem);
            }
            gg.drawString(mc.font, reserveTxt, x + boxW - mc.font.width(reserveTxt) - 6, y + 20, 0xFFCBD5E1, false);
        }
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/client/ClientModEvents.java"
package com.arsenalmod.client;

import com.arsenalmod.ArsenalMod;
import com.arsenalmod.registry.ModEntities;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = ArsenalMod.MODID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public class ClientModEvents {
    @SubscribeEvent
    public static void onRegisterKeyMappings(RegisterKeyMappingsEvent event) {
        event.register(ModKeyBindings.RELOAD_KEY);
    }

    @SubscribeEvent
    public static void onRegisterRenderers(EntityRenderersEvent.RegisterRenderers event) {
        event.registerEntityRenderer(ModEntities.BULLET.get(), BulletRenderer::new);
        event.registerEntityRenderer(ModEntities.ROCKET.get(), RocketRenderer::new);
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/client/GunAnimationEngine.java"
package com.arsenalmod.client;

import com.arsenalmod.item.*;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.HumanoidArm;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.phys.Vec3;

public class GunAnimationEngine {
    public static boolean isAiming = false;
    public static float ads = 0F, sprint = 0F;
    public static float recZ = 0F, recPitch = 0F, recRoll = 0F, recVelZ = 0F;
    public static float slide = 0F, flash = 0F, flashAngle = 0F;
    public static float pumpTimer = 0F, boltTimer = 0F, spinAngle = 0F, spinSpeed = 0F;
    public static float swayX = 0F, swayY = 0F, prevYaw = 0F, prevPitch = 0F;

    // Choreographed animated part offsets
    public static float magY = 0F, magZ = 0F, magRot = 0F;
    public static boolean magVisible = true;
    public static float relBolt = 0F, warheadSlide = 0F;
    public static float leftHandX = 0F, leftHandY = 0F, leftHandZ = 0F;
    public static float rightHandBolt = 0F;

    // FPS Hitmarker
    public static float hitTimer = 0F;
    public static boolean hitHead = false, hitKill = false;

    private static long lastNano = System.nanoTime();
    private static int lastStage = 0;

    public static void triggerHitmarker(boolean hs, boolean k) { hitTimer = 0.26F; hitHead = hs; hitKill = k; }

    public static void onLocalShot(GunType t, LocalPlayer p) {
        float aim = isAiming ? 0.45F : 1.0F;
        recVelZ += t.recoilKick * 9.5F * aim;
        recPitch = Math.min(24F, recPitch + t.recoilPitch * aim);
        recRoll = (float)((Math.random() - 0.5) * 7.5F * aim);
        slide = 1.0F; flash = 1.0F; flashAngle = (float)(Math.random() * 360.0);

        if (t == GunType.SPAS12) pumpTimer = 0.56F;
        else if (t == GunType.AWP_SNIPER) boltTimer = 0.90F;
        else if (t == GunType.MINIGUN) spinSpeed = Math.min(1300F, spinSpeed + 420F);

        if (p != null) {
            float ck = t.cameraKick * (isAiming ? 0.5F : 1.0F);
            p.setXRot(Mth.clamp(p.getXRot() - ck, -89.5F, 89.5F));
            p.setYRot(p.getYRot() + (float)((Math.random() - 0.5) * ck * 0.55F));

            Vec3 eye = p.getEyePosition(), look = p.getLookAngle();
            Vec3 right = look.cross(new Vec3(0, 1, 0)).normalize();
            Vec3 up = right.cross(look).normalize();
            Vec3 port = eye.add(look.scale(0.45)).add(right.scale(isAiming ? 0.08 : 0.24)).add(up.scale(-0.14));
            if (!t.isRocket) {
                WorldEffectsRenderer.spawnShell(port, right, up, look, t.isShotgun);
                Vec3 mz = eye.add(look.scale(0.85)).add(right.scale(isAiming ? 0.0 : 0.16)).add(up.scale(isAiming ? -0.02 : -0.10));
                WorldEffectsRenderer.spawnTracer(mz, eye.add(look.scale(35.0)));
            }
        }
    }

    public static void updateFrame() {
        long now = System.nanoTime();
        float dt = Math.min(0.05F, (now - lastNano) / 1_000_000_000.0F);
        lastNano = now;

        Minecraft mc = Minecraft.getInstance();
        LocalPlayer p = mc.player;
        boolean gunHeld = p != null && p.getMainHandItem().getItem() instanceof GunItem;
        boolean rel = false;
        if (gunHeld) {
            ItemStack st = p.getMainHandItem();
            rel = ((GunItem)st.getItem()).isReloading(st, p.level().getGameTime());
            float dy = Mth.wrapDegrees(p.getYRot() - prevYaw);
            float dp = p.getXRot() - prevPitch;
            prevYaw = p.getYRot(); prevPitch = p.getXRot();
            swayX = Mth.clamp(swayX - dy * 0.0055F, -0.09F, 0.09F);
            swayY = Mth.clamp(swayY + dp * 0.0055F, -0.07F, 0.07F);
        } else { isAiming = false; }

        swayX *= (float)Math.exp(-dt * 10.0F);
        swayY *= (float)Math.exp(-dt * 10.0F);
        hitTimer = Math.max(0F, hitTimer - dt);

        float tAds = (gunHeld && isAiming && !rel) ? 1F : 0F;
        ads += (tAds - ads) * Math.min(1F, dt * 15F);

        boolean spr = gunHeld && p.isSprinting() && !isAiming && !rel && recZ < 0.04F;
        sprint += ((spr ? 1F : 0F) - sprint) * Math.min(1F, dt * 10F);

        // Critically damped spring recoil
        recZ += recVelZ * dt;
        recVelZ += (-180F * recZ - 24F * recVelZ) * dt;
        recZ = Mth.clamp(recZ, -0.04F, 0.42F);

        recPitch *= (float)Math.exp(-dt * 12.5F);
        recRoll *= (float)Math.exp(-dt * 11.5F);
        slide *= (float)Math.exp(-dt * 22F);
        flash = Math.max(0F, flash - dt * 18F);

        if (pumpTimer > 0F) {
            float pr = pumpTimer; pumpTimer = Math.max(0F, pumpTimer - dt);
            if (pr > 0.36F && pumpTimer <= 0.36F && p != null) p.playSound(SoundEvents.PISTON_EXTEND, 0.5F, 1.6F);
            if (pr > 0.14F && pumpTimer <= 0.14F && p != null) p.playSound(SoundEvents.PISTON_CONTRACT, 0.5F, 1.85F);
        }
        if (boltTimer > 0F) {
            float pr = boltTimer; boltTimer = Math.max(0F, boltTimer - dt);
            if (pr > 0.62F && boltTimer <= 0.62F && p != null) p.playSound(SoundEvents.IRON_TRAPDOOR_OPEN, 0.48F, 1.9F);
            if (pr > 0.24F && boltTimer <= 0.24F && p != null) p.playSound(SoundEvents.IRON_TRAPDOOR_CLOSE, 0.48F, 1.8F);
        }
        spinAngle = (spinAngle + spinSpeed * dt) % 360F;
        spinSpeed *= (float)Math.exp(-dt * 3.0F);
    }

    private static float ease(float t) { t = Mth.clamp(t, 0F, 1F); return t * t * (3F - 2F * t); }

    public static float getPump() {
        if (pumpTimer <= 0F || pumpTimer > 0.44F) return 0F;
        return Mth.sin((1F - pumpTimer / 0.44F) * (float)Math.PI);
    }
    public static float getBolt() {
        if (boltTimer <= 0F || boltTimer > 0.78F) return 0F;
        return Mth.sin((1F - boltTimer / 0.78F) * (float)Math.PI);
    }

    public static boolean applyFirstPersonTransform(PoseStack ps, LocalPlayer p, HumanoidArm arm,
                                                    ItemStack stack, float pt, float equip) {
        if (!(stack.getItem() instanceof GunItem gun)) return false;
        GunType t = gun.getType();
        int side = (arm == HumanoidArm.RIGHT) ? 1 : -1;
        long gt = p.level().getGameTime();
        boolean reloading = gun.isReloading(stack, gt);
        float rel = reloading ? gun.getReloadProgress(stack, gt, pt) : 0F;

        float hipX = (t == GunType.MINIGUN ? 0.34F : 0.31F) * side;
        float hipY = (t == GunType.MINIGUN ? -0.43F : -0.28F);
        float hipZ = (t == GunType.GLOCK19 ? -0.54F : -0.62F);

        float adsX = (t == GunType.MINIGUN ? 0.12F * side : 0F);
        float adsY = -(t.sightVoxelsY / 16.0F);
        float adsZ = (t == GunType.GLOCK19 ? -0.42F : (t == GunType.AWP_SNIPER ? -0.34F : -0.44F));

        float a = ease(ads);
        float x = Mth.lerp(a, hipX, adsX);
        float y = Mth.lerp(a, hipY, adsY);
        float z = Mth.lerp(a, hipZ, adsZ);

        float time = (gt + pt) * 0.085F;
        float sw = 1F - a * 0.85F;
        float wd = Mth.lerp(pt, p.walkDistO, p.walkDist);
        float wb = Mth.lerp(pt, p.oBob, p.bob);

        x += (swayX + Mth.cos(time * 0.8F) * 0.0035F + Mth.cos(wd * (float)Math.PI) * wb * 0.18F) * sw;
        y += (swayY + Mth.sin(time * 1.6F) * 0.0035F - Math.abs(Mth.sin(wd * (float)Math.PI)) * wb * 0.20F) * sw;
        y -= ease(equip) * 0.52F;

        z += recZ; y += recZ * 0.14F;

        // Reset choreographed part offsets
        magY = 0F; magZ = 0F; magRot = 0F; magVisible = true;
        relBolt = 0F; warheadSlide = 0F;
        leftHandX = 0F; leftHandY = 0F; leftHandZ = 0F;
        rightHandBolt = getBolt();

        float rX = 0F, rY = 0F, rZ = 0F;
        if (reloading) {
            int stg = rel < 0.22F ? 1 : (rel < 0.64F ? 2 : (rel < 0.82F ? 3 : 4));
            if (stg != lastStage) {
                if (stg == 3) p.playSound(SoundEvents.IRON_TRAPDOOR_CLOSE, 0.58F, 1.72F);
                if (stg == 4) p.playSound(SoundEvents.PISTON_EXTEND, 0.48F, 1.9F);
                lastStage = stg;
            }
            float env = rel < 0.14F ? ease(rel / 0.14F) : (rel > 0.88F ? ease((1F - rel) / 0.12F) : 1F);
            rZ = 32F * env * side; rX = 16F * env; rY = 14F * env * side;
            y -= 0.055F * env;

            if (t == GunType.RPG7) {
                if (rel < 0.28F) { warheadSlide = 1F; leftHandY = -5F * ease(rel / 0.28F); }
                else if (rel < 0.78F) {
                    float f = ease((rel - 0.28F) / 0.50F);
                    warheadSlide = 1F - f;
                    leftHandZ = -9.5F * warheadSlide;
                } else {
                    float b = Mth.sin(((rel - 0.78F) / 0.22F) * (float)Math.PI);
                    z += b * 0.07F;
                }
            } else {
                if (rel >= 0.14F && rel < 0.40F) {
                    float f = ease((rel - 0.14F) / 0.26F);
                    magY = -f * 8.5F; magRot = f * 22F;
                    leftHandY = magY; leftHandZ = 3.5F * f;
                } else if (rel >= 0.40F && rel < 0.50F) {
                    magVisible = false; magY = -9F; leftHandY = -8.5F;
                } else if (rel >= 0.50F && rel < 0.72F) {
                    float f = ease((rel - 0.50F) / 0.22F);
                    magY = -(1F - f) * 8.5F; magRot = (1F - f) * 16F;
                    leftHandY = magY; leftHandZ = 3.5F * (1F - f);
                } else if (rel >= 0.72F && rel < 0.88F) {
                    float f = Mth.sin(((rel - 0.72F) / 0.16F) * (float)Math.PI);
                    y += f * 0.032F;
                    relBolt = f;
                    leftHandY = f * 1.4F; leftHandZ = f * 4.5F;
                }
            }
        } else { lastStage = 0; }

        float sp = ease(sprint);
        float pump = getPump();

        ps.translate(x - 0.11F * side * sp, y - 0.08F * sp, z);
        ps.mulPose(Axis.YP.rotationDegrees(38F * side * sp + rY - swayX * 140F * sw));
        ps.mulPose(Axis.XP.rotationDegrees(recPitch - 16F * sp + rX - ease(equip) * 38F + pump * 6.5F + swayY * 120F * sw));
        ps.mulPose(Axis.ZP.rotationDegrees(recRoll + rZ + rightHandBolt * 18F * side - swayX * 110F * sw));
        return true;
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/client/GunItemRenderer.java"
package com.arsenalmod.client;

import com.arsenalmod.item.GunItem;
import com.arsenalmod.item.GunType;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.BlockEntityWithoutLevelRenderer;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.world.item.ItemDisplayContext;
import net.minecraft.world.item.ItemStack;

public class GunItemRenderer extends BlockEntityWithoutLevelRenderer {

    public GunItemRenderer() {
        super(Minecraft.getInstance().getBlockEntityRenderDispatcher(), Minecraft.getInstance().getEntityModels());
    }

    @Override
    public void renderByItem(ItemStack stack, ItemDisplayContext ctx, PoseStack ps,
                             MultiBufferSource buffer, int light, int overlay) {
        if (!(stack.getItem() instanceof GunItem gun)) return;
        GunType type = gun.getType();
        int ammo = gun.getAmmo(stack);

        boolean firstPerson = (ctx == ItemDisplayContext.FIRST_PERSON_RIGHT_HAND
                || ctx == ItemDisplayContext.FIRST_PERSON_LEFT_HAND);

        // Hide 3D sniper model when full-screen scope overlay is active
        if (firstPerson && type.isSniper && GunAnimationEngine.ads > 0.85F) {
            return;
        }

        Minecraft mc = Minecraft.getInstance();
        boolean reloading = mc.player != null && gun.isReloading(stack, mc.player.level().getGameTime());

        ps.pushPose();
        ps.translate(0.5F, 0.5F, 0.5F);

        if (ctx == ItemDisplayContext.GUI) {
            float sc = switch (type) {
                case GLOCK19 -> 1.32F;
                case AK47, M4A1, SPAS12 -> 0.64F;
                case AWP_SNIPER -> 0.50F;
                case MINIGUN -> 0.56F;
                case RPG7 -> 0.50F;
            };
            float zCenter = switch (type) {
                case GLOCK19 -> 0.04F;
                case AK47, M4A1, SPAS12 -> 0.16F;
                case AWP_SNIPER -> 0.24F;
                case MINIGUN -> 0.18F;
                case RPG7 -> 0.14F;
            };
            ps.mulPose(Axis.ZP.rotationDegrees(22.0F));
            ps.mulPose(Axis.XP.rotationDegrees(14.0F));
            ps.mulPose(Axis.YP.rotationDegrees(-78.0F));
            ps.scale(sc, sc, sc);
            ps.translate(0.0F, -0.05F, zCenter);
        } else if (ctx == ItemDisplayContext.THIRD_PERSON_RIGHT_HAND
                || ctx == ItemDisplayContext.THIRD_PERSON_LEFT_HAND) {
            float sc = switch (type) {
                case GLOCK19 -> 0.82F;
                case MINIGUN, RPG7 -> 0.68F;
                default -> 0.76F;
            };
            ps.translate(0.0F, 0.12F, 0.05F);
            ps.scale(sc, sc, sc);
        } else if (ctx == ItemDisplayContext.GROUND) {
            float sc = (type == GunType.GLOCK19) ? 0.85F : 0.55F;
            ps.translate(0.0F, 0.08F, 0.0F);
            ps.scale(sc, sc, sc);
        } else if (ctx == ItemDisplayContext.FIXED) {
            float sc = (type == GunType.GLOCK19) ? 1.15F : 0.58F;
            ps.mulPose(Axis.YP.rotationDegrees(-90.0F));
            ps.scale(sc, sc, sc);
            ps.translate(0.0F, -0.04F, 0.15F);
        }

        GunModelGeometry.renderGun(type, ps, buffer, light, overlay, firstPerson, ammo, reloading);
        ps.popPose();
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/client/GunModelGeometry.java"
package com.arsenalmod.client;

import com.arsenalmod.ArsenalMod;
import com.arsenalmod.item.GunType;
import com.mojang.blaze3d.vertex.*;
import com.mojang.math.Axis;
import net.minecraft.client.renderer.*;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import org.joml.Matrix3f;
import org.joml.Matrix4f;

public class GunModelGeometry {
    public static final ResourceLocation ATLAS = new ResourceLocation(ArsenalMod.MODID, "textures/entity/weapons_atlas.png");

    public static final int T_GUNMETAL = 0, T_STEEL = 1, T_CHROME = 2, T_POLYMER = 3,
            T_GRIP = 4, T_RAIL = 5, T_WOOD_AK = 6, T_WOOD_DARK = 7,
            T_OLIVE = 8, T_TAN = 9, T_BRASS = 10, T_LENS = 11,
            T_RED = 12, T_GREEN = 13, T_MUZZLE_FLASH = 14, T_RED_HULL = 15,
            T_GLOVE = 16, T_SLEEVE = 17, T_CARBON = 18, T_VENT = 19;

    private static final float S = 1.0F / 16.0F;

    public static void renderGun(GunType type, PoseStack ps, MultiBufferSource buf, int light, int ov,
                                 boolean fp, int ammo, boolean reloading) {
        VertexConsumer vc = buf.getBuffer(RenderType.entityCutoutNoCull(ATLAS));
        float sl = fp ? Math.max(GunAnimationEngine.slide, GunAnimationEngine.relBolt) : 0F;
        float mY = fp ? GunAnimationEngine.magY : 0F, mR = fp ? GunAnimationEngine.magRot : 0F;
        boolean mV = !fp || GunAnimationEngine.magVisible;
        float pm = fp ? GunAnimationEngine.getPump() : 0F;
        float bt = fp ? Math.max(GunAnimationEngine.getBolt(), GunAnimationEngine.relBolt) : 0F;
        float sp = fp ? GunAnimationEngine.spinAngle : 0F;

        switch (type) {
            case GLOCK19 -> glock(ps, vc, light, ov, sl, mY, mV, ammo == 0 && !reloading, fp);
            case AK47 -> ak47(ps, vc, light, ov, sl, mY, mR, mV, fp);
            case M4A1 -> m4a1(ps, vc, light, ov, sl, mY, mV, fp);
            case SPAS12 -> spas12(ps, vc, light, ov, pm, sl, fp);
            case AWP_SNIPER -> awp(ps, vc, light, ov, bt, mY, mV, fp);
            case MINIGUN -> minigun(ps, vc, light, ov, sp, fp);
            case RPG7 -> rpg7(ps, vc, light, ov, ammo > 0 || (fp && reloading && GunAnimationEngine.warheadSlide < 0.99F),
                    fp && reloading ? GunAnimationEngine.warheadSlide : 0F, fp);
        }

        if (fp && GunAnimationEngine.flash > 0.05F) {
            muzzleFlash(ps, vc, type.muzzleVoxelsY, type.muzzleVoxelsZ,
                    type.isShotgun || type.isRocket ? 3.1F : 2.1F, GunAnimationEngine.flash, GunAnimationEngine.flashAngle);
        }
    }

    private static void hand(PoseStack ps, VertexConsumer vc, int light, int ov, float x, float y, float z,
                             float rx, float ry, float rz, boolean right) {
        ps.pushPose();
        ps.translate(x * S, y * S, z * S);
        ps.mulPose(Axis.YP.rotationDegrees(ry));
        ps.mulPose(Axis.XP.rotationDegrees(rx));
        ps.mulPose(Axis.ZP.rotationDegrees(rz));
        // Tactical gloved palm + carbon knuckle guard + forearm sleeve
        box(ps, vc, light, ov, T_GLOVE, 0, 0, 0, 2.05F, 1.95F, 2.3F);
        box(ps, vc, light, ov, T_CARBON, 0, 0.95F, -0.35F, 1.9F, 0.35F, 1.1F);
        box(ps, vc, light, ov, T_GLOVE, right ? -0.95F : 0.95F, 0.4F, -0.8F, 0.65F, 0.7F, 1.4F);
        cyl(ps, vc, light, ov, T_SLEEVE, 0, -0.25F, 4.4F, 1.18F, 1.38F, 6.8F, 2);
        box(ps, vc, light, ov, T_CARBON, 0, -0.1F, 1.45F, 2.15F, 2.05F, 0.65F); // Wrist strap
        ps.popPose();
    }

    private static void glock(PoseStack ps, VertexConsumer vc, int l, int ov, float sl, float mY, boolean mV, boolean empty, boolean fp) {
        // Sculpted polymer frame + tapered front bevel + picatinny rail
        box(ps, vc, l, ov, T_POLYMER, 0, 0.55F, -0.6F, 1.52F, 0.98F, 7.2F);
        box(ps, vc, l, ov, T_RAIL, 0, -0.02F, -2.9F, 1.12F, 0.32F, 2.6F);
        box(ps, vc, l, ov, T_POLYMER, 0, -0.82F, -0.6F, 0.55F, 0.26F, 2.3F);
        box(ps, vc, l, ov, T_POLYMER, 0, -0.32F, -1.65F, 0.55F, 1.05F, 0.28F);
        rotBox(ps, vc, l, ov, T_CHROME, 0, -0.2F, -0.15F, 0.24F, 0.85F, 0.24F, -20 - sl * 20, 0, 0);
        rotBox(ps, vc, l, ov, T_GRIP, 0, -1.85F, 1.9F, 1.45F, 4.2F, 2.05F, 17, 0, 0);
        // True cylindrical steel barrel + muzzle crown
        cyl(ps, vc, l, ov, T_CHROME, 0, 1.65F, -1.8F, 0.44F, 0.44F, 6.4F, 2);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 1.65F, -5.05F, 0.32F, 0.44F, 0.45F, 2);

        if (mV) {
            ps.pushPose(); ps.translate(0, mY * S, -mY * 0.28F * S);
            rotBox(ps, vc, l, ov, T_STEEL, 0, -2.1F, 1.95F, 1.08F, 4.0F, 1.48F, 17, 0, 0);
            rotBox(ps, vc, l, ov, T_POLYMER, 0, -4.05F, 2.52F, 1.52F, 0.52F, 2.08F, 17, 0, 0);
            rotBox(ps, vc, l, ov, T_BRASS, 0, -0.15F, 1.35F, 0.55F, 0.45F, 0.95F, 17, 0, 0);
            ps.popPose();
        }
        // Chamfered recoiling slide
        ps.pushPose(); ps.translate(0, 0, (empty ? 1.6F : sl * 2.2F) * S);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 1.62F, -0.75F, 1.62F, 1.18F, 7.4F);
        box(ps, vc, l, ov, T_STEEL, 0, 2.28F, -0.75F, 1.24F, 0.26F, 7.2F);
        for (int i = 0; i < 5; i++) box(ps, vc, l, ov, T_POLYMER, 0, 1.62F, 1.1F + i * 0.38F, 1.68F, 0.9F, 0.14F);
        box(ps, vc, l, ov, T_GUNMETAL, -0.38F, 2.55F, 2.55F, 0.32F, 0.34F, 0.42F);
        box(ps, vc, l, ov, T_GUNMETAL,  0.38F, 2.55F, 2.55F, 0.32F, 0.34F, 0.42F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN, -0.38F, 2.58F, 2.77F, 0.15F, 0.15F, 0.08F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN,  0.38F, 2.58F, 2.77F, 0.15F, 0.15F, 0.08F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_RED, 0, 2.58F, -4.1F, 0.16F, 0.2F, 0.2F);
        ps.popPose();

        if (fp) {
            hand(ps, vc, l, ov, 0.25F, -2.0F, 2.4F, 14, -10, 0, true);
            hand(ps, vc, l, ov, -0.45F + GunAnimationEngine.leftHandX, -2.2F + GunAnimationEngine.leftHandY,
                    2.0F + GunAnimationEngine.leftHandZ, 12, 16, 0, false);
        }
    }

    private static void ak47(PoseStack ps, VertexConsumer vc, int l, int ov, float sl, float mY, float mR, boolean mV, boolean fp) {
        // Stamped receiver + beveled dust cover
        box(ps, vc, l, ov, T_GUNMETAL, 0, 0.78F, -0.4F, 1.82F, 1.88F, 7.4F);
        cyl(ps, vc, l, ov, T_STEEL, 0, 1.72F, 0.2F, 0.84F, 0.84F, 6.2F, 2);
        // Sculpted Russian Oak Wood Stock + Metal Buttplate
        rotBox(ps, vc, l, ov, T_WOOD_AK, 0, 0.1F, 6.3F, 1.48F, 2.05F, 6.6F, -9, 0, 0);
        rotBox(ps, vc, l, ov, T_WOOD_AK, 0, -0.58F, 8.0F, 1.45F, 1.65F, 3.2F, -12, 0, 0);
        rotBox(ps, vc, l, ov, T_GUNMETAL, 0, -0.25F, 9.6F, 1.52F, 2.8F, 0.35F, -8, 0, 0);
        rotBox(ps, vc, l, ov, T_WOOD_DARK, 0, -1.75F, 2.2F, 1.24F, 3.6F, 1.52F, 19, 0, 0);
        box(ps, vc, l, ov, T_GUNMETAL, 0, -0.72F, 0.3F, 0.52F, 0.22F, 2.2F);
        // Sculpted Wood Handguards
        box(ps, vc, l, ov, T_WOOD_AK, 0, 0.58F, -6.5F, 1.82F, 1.38F, 5.1F);
        cyl(ps, vc, l, ov, T_WOOD_AK, 0, 1.58F, -6.3F, 0.72F, 0.72F, 4.4F, 2);
        // Cylindrical Gas Tube, Barrel & Slant Muzzle Compensator
        cyl(ps, vc, l, ov, T_STEEL, 0, 1.65F, -9.6F, 0.42F, 0.42F, 2.5F, 2);
        rotBox(ps, vc, l, ov, T_GUNMETAL, 0, 1.28F, -10.8F, 0.88F, 1.45F, 0.9F, 26, 0, 0);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 0.95F, -12.0F, 0.38F, 0.42F, 7.2F, 2);
        cyl(ps, vc, l, ov, T_CHROME, 0, 0.95F, -15.7F, 0.48F, 0.44F, 1.15F, 2);
        // Tangent Rear Sight + Hooded Front Sight
        box(ps, vc, l, ov, T_GUNMETAL, 0, 2.45F, -3.4F, 1.05F, 0.48F, 1.6F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN, -0.26F, 2.86F, -2.65F, 0.14F, 0.14F, 0.1F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN,  0.26F, 2.86F, -2.65F, 0.14F, 0.14F, 0.1F);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 1.98F, -14.4F, 0.42F, 1.75F, 0.72F);
        box(ps, vc, l, ov, T_GUNMETAL, -0.42F, 2.65F, -14.4F, 0.16F, 0.78F, 0.52F);
        box(ps, vc, l, ov, T_GUNMETAL,  0.42F, 2.65F, -14.4F, 0.16F, 0.78F, 0.52F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_RED, 0, 2.86F, -14.4F, 0.15F, 0.22F, 0.15F);

        ps.pushPose(); ps.translate(0, 0, sl * 2.7F * S);
        box(ps, vc, l, ov, T_CHROME, 0.92F, 1.45F, -1.6F, 0.25F, 0.62F, 2.7F);
        cyl(ps, vc, l, ov, T_CHROME, 1.4F, 1.45F, -2.35F, 0.22F, 0.22F, 0.95F, 0);
        ps.popPose();

        if (mV) {
            ps.pushPose(); ps.translate(0, mY * S, -mY * 0.18F * S);
            ps.mulPose(Axis.XP.rotationDegrees(-mR));
            rotBox(ps, vc, l, ov, T_GUNMETAL, 0, -1.35F, -2.75F, 1.24F, 2.6F, 2.02F, -12, 0, 0);
            rotBox(ps, vc, l, ov, T_GUNMETAL, 0, -3.55F, -3.38F, 1.22F, 2.5F, 1.98F, -24, 0, 0);
            rotBox(ps, vc, l, ov, T_STEEL,    0, -5.52F, -4.38F, 1.20F, 2.2F, 1.95F, -36, 0, 0);
            rotBox(ps, vc, l, ov, T_BRASS, 0, -0.1F, -2.5F, 0.65F, 0.45F, 1.25F, -12, 0, 0);
            ps.popPose();
        }
        if (fp) {
            hand(ps, vc, l, ov, 0.35F, -2.0F, 2.6F, 16, -8, 0, true);
            hand(ps, vc, l, ov, -1.0F + GunAnimationEngine.leftHandX, -0.3F + GunAnimationEngine.leftHandY,
                    -5.8F + GunAnimationEngine.leftHandZ, -10, 26, -12, false);
        }
    }

    private static void m4a1(PoseStack ps, VertexConsumer vc, int l, int ov, float sl, float mY, boolean mV, boolean fp) {
        box(ps, vc, l, ov, T_GUNMETAL, 0, 0.92F, -0.4F, 1.82F, 2.15F, 6.8F);
        box(ps, vc, l, ov, T_RAIL, 0, 2.12F, -0.4F, 1.12F, 0.30F, 6.8F);
        cyl(ps, vc, l, ov, T_STEEL, 0, 1.48F, 5.6F, 0.58F, 0.58F, 5.8F, 2);
        box(ps, vc, l, ov, T_TAN, 0, 0.72F, 7.8F, 1.58F, 2.9F, 3.6F);
        box(ps, vc, l, ov, T_POLYMER, 0, 0.52F, 9.75F, 1.66F, 3.2F, 0.52F);
        // Free-float M-LOK / Quad-Rail Handguard + Angled Foregrip
        box(ps, vc, l, ov, T_RAIL, 0, 1.05F, -7.2F, 1.85F, 1.88F, 6.8F);
        box(ps, vc, l, ov, T_TAN, -0.98F, 1.05F, -7.2F, 0.22F, 0.82F, 5.4F);
        box(ps, vc, l, ov, T_TAN,  0.98F, 1.05F, -7.2F, 0.22F, 0.82F, 5.4F);
        rotBox(ps, vc, l, ov, T_GRIP, 0, -0.58F, -7.6F, 1.05F, 2.1F, 1.2F, -24, 0, 0);
        rotBox(ps, vc, l, ov, T_GRIP, 0, -1.65F, 2.0F, 1.28F, 3.55F, 1.62F, 18, 0, 0);
        // True Cylindrical Barrel + Knurled Tactical Suppressor
        cyl(ps, vc, l, ov, T_STEEL, 0, 1.05F, -11.8F, 0.40F, 0.40F, 2.6F, 2);
        cyl(ps, vc, l, ov, T_CARBON, 0, 1.05F, -14.8F, 0.68F, 0.68F, 4.2F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 1.05F, -12.9F, 0.72F, 0.72F, 0.42F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 1.05F, -16.7F, 0.72F, 0.65F, 0.45F, 2);
        // Sleek Holographic Red-Dot Sight (Centered Y = +3.55)
        box(ps, vc, l, ov, T_POLYMER, 0, 2.48F, -0.8F, 1.55F, 0.52F, 2.9F);
        box(ps, vc, l, ov, T_GUNMETAL, -0.82F, 3.55F, -0.8F, 0.22F, 1.85F, 2.2F);
        box(ps, vc, l, ov, T_GUNMETAL,  0.82F, 3.55F, -0.8F, 0.22F, 1.85F, 2.2F);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 4.46F, -0.8F, 1.86F, 0.24F, 2.2F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_RED, 0, 3.55F, -0.8F, 0.13F, 0.13F, 0.13F);

        ps.pushPose(); ps.translate(0, 0, sl * 2.1F * S);
        box(ps, vc, l, ov, T_CHROME, 0.92F, 1.35F, -0.8F, 0.16F, 0.62F, 2.1F);
        box(ps, vc, l, ov, T_STEEL, 0, 1.88F, 3.1F, 1.25F, 0.34F, 0.52F);
        ps.popPose();

        if (mV) {
            ps.pushPose(); ps.translate(0, mY * S, 0);
            rotBox(ps, vc, l, ov, T_STEEL, 0, -2.2F, -2.4F, 1.18F, 4.4F, 2.12F, -7, 0, 0);
            rotBox(ps, vc, l, ov, T_TAN, 0, -4.45F, -2.65F, 1.32F, 0.58F, 2.22F, -7, 0, 0);
            box(ps, vc, l, ov, T_BRASS, 0, -0.05F, -2.2F, 0.7F, 0.45F, 1.3F);
            ps.popPose();
        }
        if (fp) {
            hand(ps, vc, l, ov, 0.35F, -1.9F, 2.4F, 16, -8, 0, true);
            hand(ps, vc, l, ov, -0.95F + GunAnimationEngine.leftHandX, -0.75F + GunAnimationEngine.leftHandY,
                    -6.8F + GunAnimationEngine.leftHandZ, -14, 24, -10, false);
        }
    }

    private static void spas12(PoseStack ps, VertexConsumer vc, int l, int ov, float pm, float sl, boolean fp) {
        box(ps, vc, l, ov, T_GUNMETAL, 0, 0.95F, -0.4F, 1.98F, 2.28F, 7.5F);
        rotBox(ps, vc, l, ov, T_STEEL, 0, 0.25F, 5.9F, 1.48F, 1.25F, 5.9F, -8, 0, 0);
        box(ps, vc, l, ov, T_POLYMER, 0, -0.35F, 8.95F, 1.65F, 3.05F, 0.6F);
        box(ps, vc, l, ov, T_STEEL, 0, 2.35F, 1.5F, 1.55F, 0.30F, 6.2F);
        rotBox(ps, vc, l, ov, T_GRIP, 0, -1.7F, 2.35F, 1.38F, 3.75F, 1.72F, 18, 0, 0);
        // Ventilated Heatshield + Smooth Cylindrical Barrel & Mag Tube
        box(ps, vc, l, ov, T_VENT, 0, 1.52F, -8.5F, 1.82F, 1.48F, 8.8F);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 1.38F, -13.6F, 0.56F, 0.58F, 2.6F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 0.08F, -8.7F, 0.50F, 0.50F, 9.2F, 2);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 0.72F, -12.9F, 1.25F, 1.95F, 0.62F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN, -0.36F, 2.65F, -1.6F, 0.14F, 0.14F, 0.08F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN,  0.36F, 2.65F, -1.6F, 0.14F, 0.14F, 0.08F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_RED, 0, 2.65F, -14.1F, 0.18F, 0.2F, 0.18F);

        ps.pushPose(); ps.translate(0, 0, Math.max(sl, pm) * 2.4F * S);
        box(ps, vc, l, ov, T_CHROME, 1.0F, 1.3F, -1.3F, 0.16F, 0.72F, 2.4F);
        ps.popPose();

        // Sliding Ribbed Pump Forend + Locked Left Hand
        ps.pushPose(); ps.translate(0, 0, pm * 3.3F * S);
        cyl(ps, vc, l, ov, T_GRIP, 0, -0.05F, -8.0F, 1.12F, 1.12F, 4.9F, 2);
        for (int i = 0; i < 5; i++) cyl(ps, vc, l, ov, T_POLYMER, 0, -0.05F, -10.0F + i * 0.95F, 1.18F, 1.18F, 0.25F, 2);
        if (fp) hand(ps, vc, l, ov, -1.05F + GunAnimationEngine.leftHandX, -0.85F + GunAnimationEngine.leftHandY,
                -7.2F + GunAnimationEngine.leftHandZ, -10, 24, -10, false);
        ps.popPose();
        if (fp) hand(ps, vc, l, ov, 0.35F, -1.95F, 2.75F, 16, -8, 0, true);
    }

    private static void awp(PoseStack ps, VertexConsumer vc, int l, int ov, float bt, float mY, boolean mV, boolean fp) {
        // Olive Drab Iconic AWP Chassis + Adjustable Cheek Riser
        box(ps, vc, l, ov, T_OLIVE, 0, 0.55F, -0.5F, 1.98F, 2.0F, 8.4F);
        box(ps, vc, l, ov, T_OLIVE, 0, 0.65F, -7.4F, 1.82F, 1.68F, 6.0F);
        box(ps, vc, l, ov, T_OLIVE, 0, 0.82F, 6.4F, 1.75F, 1.12F, 6.8F);
        box(ps, vc, l, ov, T_OLIVE, 0, -1.25F, 6.6F, 1.58F, 1.02F, 6.2F);
        box(ps, vc, l, ov, T_OLIVE, 0, -0.2F, 9.0F, 1.78F, 3.1F, 1.8F);
        box(ps, vc, l, ov, T_POLYMER, 0, 1.78F, 6.5F, 1.65F, 0.85F, 3.4F);
        box(ps, vc, l, ov, T_POLYMER, 0, -0.2F, 10.1F, 1.84F, 3.2F, 0.62F);
        rotBox(ps, vc, l, ov, T_GRIP, 0, -1.2F, 2.7F, 1.44F, 3.2F, 1.7F, 15, 0, 0);
        cyl(ps, vc, l, ov, T_GUNMETAL, -0.88F, -0.55F, -7.8F, 0.24F, 0.24F, 5.0F, 2);
        cyl(ps, vc, l, ov, T_GUNMETAL,  0.88F, -0.55F, -7.8F, 0.24F, 0.24F, 5.0F, 2);
        // Cylindrical Heavy Free-Floated Barrel + Tank Muzzle Brake
        box(ps, vc, l, ov, T_GUNMETAL, 0, 1.5F, -1.2F, 1.68F, 1.15F, 7.2F);
        cyl(ps, vc, l, ov, T_STEEL, 0, 1.35F, -15.0F, 0.44F, 0.54F, 10.8F, 2);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 1.35F, -20.8F, 1.68F, 1.18F, 1.75F);
        box(ps, vc, l, ov, T_POLYMER, 0, 1.35F, -20.8F, 1.74F, 0.52F, 0.48F);
        // True Cylindrical High-Power Sniper Scope + Tapered Conical Objective Bell + Lenses
        box(ps, vc, l, ov, T_GUNMETAL, 0, 2.55F, -2.8F, 1.18F, 1.15F, 0.82F);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 2.55F,  0.6F, 1.18F, 1.15F, 0.82F);
        cyl(ps, vc, l, ov, T_CARBON, 0, 3.7F, -1.2F, 0.68F, 0.68F, 7.8F, 2);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 3.7F, -6.5F, 1.05F, 0.72F, 3.2F, 2);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 3.7F,  3.3F, 0.72F, 0.90F, 1.9F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 4.65F, -1.1F, 0.38F, 0.38F, 0.68F, 1);
        cyl(ps, vc, l, ov, T_STEEL, 0.95F, 3.7F, -1.1F, 0.38F, 0.38F, 0.68F, 0);
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_LENS, 0, 3.7F, -8.12F, 0.88F, 0.88F, 0.1F, 2);
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_LENS, 0, 3.7F,  4.28F, 0.74F, 0.74F, 0.1F, 2);

        // Animated Bolt-Action Handle
        ps.pushPose();
        ps.translate(0.92F * S, 1.55F * S, (1.4F + bt * 2.5F) * S);
        ps.mulPose(Axis.ZP.rotationDegrees(bt * 56F));
        cyl(ps, vc, l, ov, T_CHROME, 0.55F, 0, 0, 0.18F, 0.18F, 1.25F, 0);
        cyl(ps, vc, l, ov, T_CARBON, 1.25F, 0, 0, 0.34F, 0.34F, 0.62F, 0);
        ps.popPose();

        if (mV) {
            ps.pushPose(); ps.translate(0, mY * S, 0);
            box(ps, vc, l, ov, T_GUNMETAL, 0, -1.65F, -2.0F, 1.32F, 2.75F, 2.75F);
            box(ps, vc, l, ov, T_BRASS, 0, -0.2F, -2.0F, 0.72F, 0.45F, 1.75F);
            ps.popPose();
        }
        if (fp) {
            float rx = 0.35F + bt * 1.4F, ry = -1.65F + bt * 2.4F, rz = 3.1F + bt * 0.8F;
            hand(ps, vc, l, ov, rx, ry, rz, 14 - bt * 20, -10, 0, true);
            hand(ps, vc, l, ov, -1.0F + GunAnimationEngine.leftHandX, -0.35F + GunAnimationEngine.leftHandY,
                    -6.5F + GunAnimationEngine.leftHandZ, -10, 26, -12, false);
        }
    }

    private static void minigun(PoseStack ps, VertexConsumer vc, int l, int ov, float spin, boolean fp) {
        // True Cylindrical Motor Housing + Perforated Shroud + Cylindrical Ammo Drum
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 0.45F, 1.2F, 1.98F, 1.98F, 6.8F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 0.45F, 4.9F, 1.65F, 1.35F, 1.3F, 2);
        cyl(ps, vc, l, ov, T_VENT, 0, 0.45F, -3.2F, 2.12F, 2.12F, 2.4F, 2);
        box(ps, vc, l, ov, T_POLYMER, 0, 3.6F, -1.8F, 3.4F, 0.62F, 0.82F);
        box(ps, vc, l, ov, T_STEEL, -1.55F, 2.25F, -1.8F, 0.52F, 2.6F, 0.72F);
        box(ps, vc, l, ov, T_STEEL,  1.55F, 2.25F, -1.8F, 0.52F, 2.6F, 0.72F);
        cyl(ps, vc, l, ov, T_GRIP, 0, 0.45F, 6.4F, 0.36F, 0.36F, 3.2F, 0);
        box(ps, vc, l, ov, T_GUNMETAL, -1.35F, 0.45F, 5.6F, 0.42F, 0.62F, 1.4F);
        box(ps, vc, l, ov, T_GUNMETAL,  1.35F, 0.45F, 5.6F, 0.42F, 0.62F, 1.4F);
        cyl(ps, vc, l, ov, T_OLIVE, -2.65F, -2.35F, 0.5F, 1.85F, 1.85F, 4.4F, 2);
        rotBox(ps, vc, l, ov, T_BRASS, -1.65F, -0.55F, 0.4F, 1.2F, 1.65F, 1.9F, 0, 0, -28);

        // 6 Smooth Cylindrical Spinning Barrels!
        ps.pushPose();
        ps.translate(0, 0.45F * S, 0);
        ps.mulPose(Axis.ZP.rotationDegrees(spin));
        for (int i = 0; i < 6; i++) {
            float rad = (float)Math.toRadians(i * 60.0);
            cyl(ps, vc, l, ov, (i % 2 == 0) ? T_CHROME : T_STEEL,
                    Mth.cos(rad) * 1.32F, Mth.sin(rad) * 1.32F, -9.8F, 0.30F, 0.30F, 13.0F, 2);
        }
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 0, -8.0F, 1.82F, 1.82F, 0.72F, 2);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 0, -14.2F, 1.82F, 1.82F, 0.85F, 2);
        ps.popPose();

        if (fp) {
            hand(ps, vc, l, ov, 0.6F, 0.4F, 6.4F, 0, -8, 0, true);
            hand(ps, vc, l, ov, -1.1F, 3.65F, -1.8F, -25, 22, -25, false);
        }
    }

    private static void rpg7(PoseStack ps, VertexConsumer vc, int l, int ov, boolean hasWh, float whSl, boolean fp) {
        // Authentic Cylindrical Launch Tube + Walnut Heatguard + Conical Venturi Exhaust!
        cyl(ps, vc, l, ov, T_OLIVE, 0, 1.2F, -1.0F, 1.15F, 1.15F, 17.6F, 2);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 1.2F, -9.8F, 1.34F, 1.34F, 0.95F, 2);
        cyl(ps, vc, l, ov, T_WOOD_DARK, 0, 1.2F, 1.6F, 1.42F, 1.42F, 6.6F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 1.2F, -1.2F, 1.48F, 1.48F, 0.42F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 1.2F,  4.4F, 1.48F, 1.48F, 0.42F, 2);
        // Tapered Flared Venturi Exhaust Cone
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 1.2F, 9.6F, 1.22F, 1.88F, 4.2F, 2);
        cyl(ps, vc, l, ov, T_POLYMER,  0, 1.2F, 11.8F, 1.92F, 1.95F, 0.45F, 2);
        rotBox(ps, vc, l, ov, T_WOOD_DARK, 0, -1.2F, -3.2F, 1.25F, 3.4F, 1.52F, 16, 0, 0);
        rotBox(ps, vc, l, ov, T_WOOD_DARK, 0, -1.1F,  2.2F, 1.25F, 3.1F, 1.48F, -12, 0, 0);
        // PGO-7 Cylindrical Side Optic + Luminous Iron Sights
        cyl(ps, vc, l, ov, T_GUNMETAL, -1.65F, 2.35F, -2.2F, 0.58F, 0.65F, 3.5F, 2);
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_LENS, -1.65F, 2.35F, -3.98F, 0.46F, 0.46F, 0.1F, 2);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 2.95F, -8.6F, 0.32F, 1.45F, 0.42F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_RED, 0, 3.35F, -8.6F, 0.2F, 0.2F, 0.2F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN, -0.28F, 3.35F, -2.3F, 0.15F, 0.15F, 0.1F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN,  0.28F, 3.35F, -2.3F, 0.15F, 0.15F, 0.1F);

        // Animated Conical PG-7V HEAT Warhead
        if (hasWh) {
            ps.pushPose();
            ps.translate(0, 0, -whSl * 9.5F * S);
            cyl(ps, vc, l, ov, T_STEEL, 0, 1.2F, -10.8F, 0.85F, 0.85F, 2.2F, 2);
            cyl(ps, vc, l, ov, T_OLIVE, 0, 1.2F, -12.6F, 1.82F, 1.45F, 2.4F, 2);
            cyl(ps, vc, l, ov, T_BRASS, 0, 1.2F, -12.8F, 1.88F, 1.88F, 0.48F, 2);
            cyl(ps, vc, l, ov, T_OLIVE, 0, 1.2F, -14.8F, 0.85F, 1.80F, 2.2F, 2);
            cyl(ps, vc, l, ov, T_STEEL, 0, 1.2F, -16.4F, 0.42F, 0.82F, 1.2F, 2);
            cyl(ps, vc, l, ov, T_BRASS, 0, 1.2F, -17.4F, 0.22F, 0.42F, 0.95F, 2);
            ps.popPose();
        }
        if (fp) {
            hand(ps, vc, l, ov, 0.35F, -1.6F, -2.8F, 16, -8, 0, true);
            hand(ps, vc, l, ov, -0.85F + GunAnimationEngine.leftHandX, -1.4F + GunAnimationEngine.leftHandY,
                    2.4F + GunAnimationEngine.leftHandZ, -10, 22, -8, false);
        }
    }

    public static void renderRocket3D(PoseStack ps, MultiBufferSource buf, int light) {
        VertexConsumer vc = buf.getBuffer(RenderType.entityCutoutNoCull(ATLAS));
        int ov = OverlayTexture.NO_OVERLAY;
        // Oriented pointing along +Z
        cyl(ps, vc, light, ov, T_STEEL, 0, 0, -4.5F, 0.55F, 0.55F, 6.2F, 2);
        box(ps, vc, light, ov, T_GUNMETAL, 0, 0, -7.2F, 3.8F, 0.24F, 1.9F);
        box(ps, vc, light, ov, T_GUNMETAL, 0, 0, -7.2F, 0.24F, 3.8F, 1.9F);
        cyl(ps, vc, light, ov, T_OLIVE, 0, 0, 0.2F, 1.45F, 1.80F, 2.6F, 2);
        cyl(ps, vc, light, ov, T_BRASS, 0, 0, 0.4F, 1.86F, 1.86F, 0.52F, 2);
        cyl(ps, vc, light, ov, T_OLIVE, 0, 0, 2.5F, 1.78F, 0.78F, 2.2F, 2);
        cyl(ps, vc, light, ov, T_BRASS, 0, 0, 4.2F, 0.52F, 0.18F, 1.4F, 2);
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, -8.8F, 0.35F, 1.05F, 2.8F, 2);
    }

    public static void renderBullet3D(PoseStack ps, MultiBufferSource buf) {
        VertexConsumer vc = buf.getBuffer(RenderType.entityCutoutNoCull(ATLAS));
        int ov = OverlayTexture.NO_OVERLAY;
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_BRASS, 0, 0, 0.2F, 0.22F, 0.10F, 2.4F, 2);
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, -1.6F, 0.16F, 0.20F, 2.6F, 2);
    }

    private static void muzzleFlash(PoseStack ps, VertexConsumer vc, float y, float z, float size, float alpha, float angle) {
        int ov = OverlayTexture.NO_OVERLAY;
        float sc = size * (0.65F + 0.55F * alpha);
        ps.pushPose();
        ps.translate(0, y * S, (z - 0.8F) * S);
        ps.mulPose(Axis.ZP.rotationDegrees(angle));
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, 0, sc * 2.2F, sc * 0.42F, sc * 0.32F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, 0, sc * 0.42F, sc * 2.2F, sc * 0.32F);
        rotBox(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, 0, sc * 1.65F, sc * 0.34F, sc * 0.32F, 0, 0, 45);
        rotBox(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, 0, sc * 1.65F, sc * 0.34F, sc * 0.32F, 0, 0, -45);
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, -sc * 0.55F, 0.12F * sc, 0.35F * sc, sc * 1.6F, 2);
        ps.popPose();
    }

    private static void rotBox(PoseStack ps, VertexConsumer vc, int light, int ov, int tile,
                               float cx, float cy, float cz, float w, float h, float d,
                               float rx, float ry, float rz) {
        ps.pushPose();
        ps.translate(cx * S, cy * S, cz * S);
        if (ry != 0) ps.mulPose(Axis.YP.rotationDegrees(ry));
        if (rx != 0) ps.mulPose(Axis.XP.rotationDegrees(rx));
        if (rz != 0) ps.mulPose(Axis.ZP.rotationDegrees(rz));
        box(ps, vc, light, ov, tile, 0, 0, 0, w, h, d);
        ps.popPose();
    }

    // Smooth 8-sided cylinder/cone/frustum along X (axis=0), Y (axis=1), or Z (axis=2)
    // r1 = radius at -len/2, r2 = radius at +len/2
    public static void cyl(PoseStack ps, VertexConsumer vc, int light, int ov, int tile,
                           float cx, float cy, float cz, float r1, float r2, float len, int axis) {
        int segs = 8;
        int col = tile % 8;
        int row = tile / 8;
        float u0 = (col * 32.0F + 0.5F) / 256.0F;
        float u1 = ((col + 1) * 32.0F - 0.5F) / 256.0F;
        float v0 = (row * 32.0F + 0.5F) / 256.0F;
        float v1 = ((row + 1) * 32.0F - 0.5F) / 256.0F;

        ps.pushPose();
        ps.translate(cx * S, cy * S, cz * S);
        if (axis == 0) {
            ps.mulPose(Axis.YP.rotationDegrees(90.0F));
        } else if (axis == 1) {
            ps.mulPose(Axis.XP.rotationDegrees(-90.0F));
        }

        PoseStack.Pose pose = ps.last();
        Matrix4f m = pose.pose();
        Matrix3f n = pose.normal();

        float zA = -len * 0.5F * S;
        float zB =  len * 0.5F * S;
        float radA = r1 * S;
        float radB = r2 * S;
        float um = (u0 + u1) * 0.5F;
        float vm = (v0 + v1) * 0.5F;

        for (int i = 0; i < segs; i++) {
            double a0 = (2.0 * Math.PI * i) / segs;
            double a1 = (2.0 * Math.PI * (i + 1)) / segs;
            float c0 = (float) Math.cos(a0), s0 = (float) Math.sin(a0);
            float c1 = (float) Math.cos(a1), s1 = (float) Math.sin(a1);
            float nmx = (float) Math.cos((a0 + a1) * 0.5);
            float nmy = (float) Math.sin((a0 + a1) * 0.5);

            int shade = (int) (200 + nmy * 48 + nmx * 10);
            shade = Mth.clamp(shade, 145, 255);

            // Side quad
            quad(vc, m, n,
                 c0 * radA, s0 * radA, zA,
                 c1 * radA, s1 * radA, zA,
                 c1 * radB, s1 * radB, zB,
                 c0 * radB, s0 * radB, zB,
                 u0, v0, u1, v1, shade, light, ov, nmx, nmy, 0);

            // Front cap (-Z)
            if (radA > 0.0001F) {
                quad(vc, m, n,
                     0, 0, zA,
                     c1 * radA, s1 * radA, zA,
                     c0 * radA, s0 * radA, zA,
                     0, 0, zA,
                     u0, v0, um, vm, 205, light, ov, 0, 0, -1);
            }
            // Back cap (+Z)
            if (radB > 0.0001F) {
                quad(vc, m, n,
                     0, 0, zB,
                     c0 * radB, s0 * radB, zB,
                     c1 * radB, s1 * radB, zB,
                     0, 0, zB,
                     u0, v0, um, vm, 205, light, ov, 0, 0, 1);
            }
        }
        ps.popPose();
    }

    public static void box(PoseStack ps, VertexConsumer vc, int light, int ov, int tile,
                           float cx, float cy, float cz, float w, float h, float d) {
        float x0 = (cx - w * 0.5F) * S, x1 = (cx + w * 0.5F) * S;
        float y0 = (cy - h * 0.5F) * S, y1 = (cy + h * 0.5F) * S;
        float z0 = (cz - d * 0.5F) * S, z1 = (cz + d * 0.5F) * S;

        int col = tile % 8;
        int row = tile / 8;
        float u0 = (col * 32.0F + 0.5F) / 256.0F;
        float u1 = ((col + 1) * 32.0F - 0.5F) / 256.0F;
        float v0 = (row * 32.0F + 0.5F) / 256.0F;
        float v1 = ((row + 1) * 32.0F - 0.5F) / 256.0F;

        PoseStack.Pose pose = ps.last();
        Matrix4f m = pose.pose();
        Matrix3f n = pose.normal();

        // +Y Top
        quad(vc, m, n, x0, y1, z1, x1, y1, z1, x1, y1, z0, x0, y1, z0, u0, v0, u1, v1, 255, light, ov, 0, 1, 0);
        // -Y Bottom
        quad(vc, m, n, x0, y0, z0, x1, y0, z0, x1, y0, z1, x0, y0, z1, u0, v0, u1, v1, 165, light, ov, 0, -1, 0);
        // -Z North (Front)
        quad(vc, m, n, x1, y0, z0, x0, y0, z0, x0, y1, z0, x1, y1, z0, u0, v0, u1, v1, 215, light, ov, 0, 0, -1);
        // +Z South (Back)
        quad(vc, m, n, x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1, u0, v0, u1, v1, 215, light, ov, 0, 0, 1);
        // -X West (Left)
        quad(vc, m, n, x0, y0, z0, x0, y0, z1, x0, y1, z1, x0, y1, z0, u0, v0, u1, v1, 195, light, ov, -1, 0, 0);
        // +X East (Right)
        quad(vc, m, n, x1, y0, z1, x1, y0, z0, x1, y1, z0, x1, y1, z1, u0, v0, u1, v1, 235, light, ov, 1, 0, 0);
    }

    private static void quad(VertexConsumer vc, Matrix4f m, Matrix3f n,
                             float x1, float y1, float z1,
                             float x2, float y2, float z2,
                             float x3, float y3, float z3,
                             float x4, float y4, float z4,
                             float u0, float v0, float u1, float v1,
                             int shade, int light, int ov,
                             float nx, float ny, float nz) {
        vc.vertex(m, x1, y1, z1).color(shade, shade, shade, 255).uv(u0, v1).overlayCoords(ov).uv2(light).normal(n, nx, ny, nz).endVertex();
        vc.vertex(m, x2, y2, z2).color(shade, shade, shade, 255).uv(u1, v1).overlayCoords(ov).uv2(light).normal(n, nx, ny, nz).endVertex();
        vc.vertex(m, x3, y3, z3).color(shade, shade, shade, 255).uv(u1, v0).overlayCoords(ov).uv2(light).normal(n, nx, ny, nz).endVertex();
        vc.vertex(m, x4, y4, z4).color(shade, shade, shade, 255).uv(u0, v0).overlayCoords(ov).uv2(light).normal(n, nx, ny, nz).endVertex();
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/client/ModKeyBindings.java"
package com.arsenalmod.client;

import com.mojang.blaze3d.platform.InputConstants;
import net.minecraft.client.KeyMapping;
import net.minecraftforge.client.settings.KeyConflictContext;
import org.lwjgl.glfw.GLFW;

public class ModKeyBindings {
    public static final KeyMapping RELOAD_KEY = new KeyMapping(
            "key.arsenalmod.reload",
            KeyConflictContext.IN_GAME,
            InputConstants.Type.KEYSYM,
            GLFW.GLFW_KEY_R,
            "key.categories.arsenalmod"
    );
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/client/RocketRenderer.java"
package com.arsenalmod.client;

import com.arsenalmod.entity.RocketEntity;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;

public class RocketRenderer extends EntityRenderer<RocketEntity> {
    public RocketRenderer(EntityRendererProvider.Context ctx) {
        super(ctx);
    }

    @Override
    public void render(RocketEntity entity, float entityYaw, float partialTick,
                       PoseStack ps, MultiBufferSource buffer, int light) {
        ps.pushPose();
        float yaw = Mth.lerp(partialTick, entity.yRotO, entity.getYRot());
        float pitch = Mth.lerp(partialTick, entity.xRotO, entity.getXRot());
        ps.mulPose(Axis.YP.rotationDegrees(yaw));
        ps.mulPose(Axis.XP.rotationDegrees(-pitch));
        GunModelGeometry.renderRocket3D(ps, buffer, light);
        ps.popPose();
        super.render(entity, entityYaw, partialTick, ps, buffer, light);
    }

    @Override
    public ResourceLocation getTextureLocation(RocketEntity entity) {
        return GunModelGeometry.ATLAS;
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/client/WorldEffectsRenderer.java"
package com.arsenalmod.client;

import com.arsenalmod.ArsenalMod;
import com.mojang.blaze3d.vertex.*;
import com.mojang.math.Axis;
import net.minecraft.client.Camera;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.*;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;
import org.joml.Matrix3f;
import org.joml.Matrix4f;
import java.util.*;

public class WorldEffectsRenderer {
    public static final ResourceLocation HOLE_TEX = new ResourceLocation(ArsenalMod.MODID, "textures/entity/bullet_hole.png");

    private static class BulletHole {
        double x, y, z; Direction dir; float roll, age;
        BulletHole(double x, double y, double z, Direction d) {
            this.x = x; this.y = y; this.z = z; this.dir = d;
            this.roll = (float)(Math.random() * 360.0);
        }
    }

    private static class ShellCasing {
        double x, y, z, vx, vy, vz; float rx, ry, vrx, vry, age; boolean shotgun;
        ShellCasing(double x, double y, double z, double vx, double vy, double vz, boolean sh) {
            this.x = x; this.y = y; this.z = z; this.vx = vx; this.vy = vy; this.vz = vz;
            this.shotgun = sh;
            this.vrx = (float)(420 + Math.random() * 480);
            this.vry = (float)(280 + Math.random() * 420);
        }
    }

    private static class Tracer {
        Vec3 a, b; float age;
        Tracer(Vec3 a, Vec3 b) { this.a = a; this.b = b; }
    }

    private static final List<BulletHole> HOLES = new ArrayList<>();
    private static final List<ShellCasing> SHELLS = new ArrayList<>();
    private static final List<Tracer> TRACERS = new ArrayList<>();
    private static long lastNano = System.nanoTime();

    public static void addBulletHole(double x, double y, double z, Direction dir) {
        if (HOLES.size() >= 180) HOLES.remove(0);
        HOLES.add(new BulletHole(x, y, z, dir));
    }

    public static void spawnShell(Vec3 pos, Vec3 right, Vec3 up, Vec3 look, boolean shotgun) {
        if (SHELLS.size() >= 90) SHELLS.remove(0);
        double spd = 2.0 + Math.random() * 1.1;
        Vec3 v = right.scale(spd).add(up.scale(1.1 + Math.random() * 0.7)).add(look.scale(-0.35 + (Math.random() - 0.5) * 0.4));
        SHELLS.add(new ShellCasing(pos.x, pos.y, pos.z, v.x, v.y, v.z, shotgun));
    }

    public static void spawnTracer(Vec3 start, Vec3 end) {
        if (TRACERS.size() >= 40) TRACERS.remove(0);
        TRACERS.add(new Tracer(start, end));
    }

    public static void render(PoseStack ps, Camera cam, float partialTick) {
        Minecraft mc = Minecraft.getInstance();
        Level lvl = mc.level;
        if (lvl == null) return;

        long now = System.nanoTime();
        float dt = Math.min(0.05F, (now - lastNano) / 1_000_000_000.0F);
        lastNano = now;

        Vec3 cp = cam.getPosition();
        MultiBufferSource.BufferSource bs = mc.renderBuffers().bufferSource();

        // 1. Update & Render 3D Bullet Holes on Blocks
        if (!HOLES.isEmpty()) {
            VertexConsumer vc = bs.getBuffer(RenderType.entityTranslucent(HOLE_TEX));
            Iterator<BulletHole> it = HOLES.iterator();
            while (it.hasNext()) {
                BulletHole h = it.next();
                h.age += dt;
                if (h.age > 24.0F) { it.remove(); continue; }
                int alpha = h.age > 20.0F ? (int)(255 * (1.0F - (h.age - 20.0F) / 4.0F)) : 255;
                int light = LevelRenderer.getLightColor(lvl, BlockPos.containing(
                        h.x + h.dir.getStepX() * 0.1, h.y + h.dir.getStepY() * 0.1, h.z + h.dir.getStepZ() * 0.1));

                ps.pushPose();
                ps.translate(h.x - cp.x + h.dir.getStepX() * 0.008,
                             h.y - cp.y + h.dir.getStepY() * 0.008,
                             h.z - cp.z + h.dir.getStepZ() * 0.008);
                switch (h.dir) {
                    case UP -> ps.mulPose(Axis.XP.rotationDegrees(-90));
                    case DOWN -> ps.mulPose(Axis.XP.rotationDegrees(90));
                    case NORTH -> ps.mulPose(Axis.YP.rotationDegrees(180));
                    case EAST -> ps.mulPose(Axis.YP.rotationDegrees(90));
                    case WEST -> ps.mulPose(Axis.YP.rotationDegrees(-90));
                    default -> {}
                }
                ps.mulPose(Axis.ZP.rotationDegrees(h.roll));
                PoseStack.Pose pose = ps.last();
                Matrix4f m = pose.pose(); Matrix3f n = pose.normal();
                float r = 0.095F;
                vc.vertex(m, -r, -r, 0).color(255,255,255,alpha).uv(0,1).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(light).normal(n,0,0,1).endVertex();
                vc.vertex(m,  r, -r, 0).color(255,255,255,alpha).uv(1,1).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(light).normal(n,0,0,1).endVertex();
                vc.vertex(m,  r,  r, 0).color(255,255,255,alpha).uv(1,0).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(light).normal(n,0,0,1).endVertex();
                vc.vertex(m, -r,  r, 0).color(255,255,255,alpha).uv(0,0).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(light).normal(n,0,0,1).endVertex();
                ps.popPose();
            }
            bs.endBatch(RenderType.entityTranslucent(HOLE_TEX));
        }

        // 2. Update & Render 3D Spinning Ejecting Shell Casings & Luminous Tracers
        if (!SHELLS.isEmpty() || !TRACERS.isEmpty()) {
            VertexConsumer vc = bs.getBuffer(RenderType.entityCutoutNoCull(GunModelGeometry.ATLAS));
            Iterator<ShellCasing> sit = SHELLS.iterator();
            while (sit.hasNext()) {
                ShellCasing s = sit.next();
                s.age += dt;
                if (s.age > 5.0F) { sit.remove(); continue; }
                s.vy -= 14.5 * dt;
                double nx = s.x + s.vx * dt, ny = s.y + s.vy * dt, nz = s.z + s.vz * dt;
                if (lvl.getBlockState(BlockPos.containing(nx, ny - 0.03, nz)).blocksMotion()) {
                    s.vy = -s.vy * 0.35; s.vx *= 0.55; s.vz *= 0.55; s.vrx *= 0.4F; s.vry *= 0.4F;
                } else { s.x = nx; s.y = ny; s.z = nz; }
                s.rx += s.vrx * dt; s.ry += s.vry * dt;

                int light = LevelRenderer.getLightColor(lvl, BlockPos.containing(s.x, s.y, s.z));
                ps.pushPose();
                ps.translate(s.x - cp.x, s.y - cp.y, s.z - cp.z);
                ps.mulPose(Axis.YP.rotationDegrees(s.ry));
                ps.mulPose(Axis.XP.rotationDegrees(s.rx));
                if (s.shotgun) {
                    GunModelGeometry.cyl(ps, vc, light, OverlayTexture.NO_OVERLAY, GunModelGeometry.T_RED_HULL, 0, 0, 0.25F, 0.24F, 0.24F, 0.9F, 2);
                    GunModelGeometry.cyl(ps, vc, light, OverlayTexture.NO_OVERLAY, GunModelGeometry.T_BRASS, 0, 0, -0.35F, 0.25F, 0.25F, 0.35F, 2);
                } else {
                    GunModelGeometry.cyl(ps, vc, light, OverlayTexture.NO_OVERLAY, GunModelGeometry.T_BRASS, 0, 0, 0, 0.14F, 0.14F, 0.65F, 2);
                }
                ps.popPose();
            }

            Iterator<Tracer> tit = TRACERS.iterator();
            while (tit.hasNext()) {
                Tracer tr = tit.next();
                tr.age += dt;
                if (tr.age > 0.075F) { tit.remove(); continue; }
                Vec3 dir = tr.b.subtract(tr.a);
                double len = Math.min(28.0, dir.length());
                if (len < 0.2) continue;
                Vec3 d = dir.normalize();
                double hz = Math.sqrt(d.x * d.x + d.z * d.z);
                float yaw = (float)(Math.atan2(d.x, d.z) * 180.0 / Math.PI);
                float pitch = (float)(Math.atan2(d.y, hz) * 180.0 / Math.PI);
                Vec3 mid = tr.a.add(d.scale(len * 0.5));
                ps.pushPose();
                ps.translate(mid.x - cp.x, mid.y - cp.y, mid.z - cp.z);
                ps.mulPose(Axis.YP.rotationDegrees(yaw));
                ps.mulPose(Axis.XP.rotationDegrees(-pitch));
                GunModelGeometry.box(ps, vc, LightTexture.FULL_BRIGHT, OverlayTexture.NO_OVERLAY,
                        GunModelGeometry.T_MUZZLE_FLASH, 0, 0, 0, 0.22F, 0.22F, (float)(len * 16.0));
                ps.popPose();
            }
            bs.endBatch(RenderType.entityCutoutNoCull(GunModelGeometry.ATLAS));
        }
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/entity/BulletEntity.java"
package com.arsenalmod.entity;

import com.arsenalmod.network.*;
import com.arsenalmod.registry.ModEntities;
import net.minecraft.core.particles.*;
import net.minecraft.server.level.*;
import net.minecraft.sounds.*;
import net.minecraft.world.entity.*;
import net.minecraft.world.entity.projectile.ThrowableProjectile;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.*;
import net.minecraftforge.network.PacketDistributor;

public class BulletEntity extends ThrowableProjectile {
    private float damage = 14.0F;
    private float armorPen = 0.35F;

    public BulletEntity(EntityType<? extends BulletEntity> type, Level level) { super(type, level); }
    public BulletEntity(Level level, LivingEntity shooter, float damage, float armorPen) {
        super(ModEntities.BULLET.get(), shooter, level);
        this.damage = damage;
        this.armorPen = armorPen;
    }

    @Override protected void defineSynchedData() {}
    @Override protected float getGravity() { return 0.005F; }

    @Override
    public void tick() {
        super.tick();
        if (this.level().isClientSide) {
            this.level().addParticle(ParticleTypes.SMOKE, getX(), getY(), getZ(), 0, 0, 0);
        }
        if (this.tickCount > 70) this.discard();
    }

    @Override
    protected void onHitEntity(EntityHitResult res) {
        super.onHitEntity(res);
        Entity target = res.getEntity(), owner = this.getOwner();
        if (target == owner || this.level().isClientSide) return;

        double relY = (res.getLocation().y - target.getY()) / Math.max(0.2, target.getBbHeight());
        boolean headshot = relY >= 0.72;
        float zoneMul = headshot ? 2.2F : (relY < 0.32 ? 0.78F : 1.0F);
        float finalDmg = this.damage * zoneMul;

        // Realistic armor penetration scaling
        if (target instanceof LivingEntity living) {
            float armor = living.getArmorValue();
            if (armor > 0) finalDmg *= (1.0F + this.armorPen * (armor / 16.0F));
        }

        target.invulnerableTime = 0;
        boolean hurt = target.hurt(this.damageSources().thrown(this, owner), finalDmg);
        boolean killed = target instanceof LivingEntity lv && lv.isDeadOrDying();

        if (hurt && owner instanceof ServerPlayer sp) {
            ModNetwork.INSTANCE.send(PacketDistributor.PLAYER.with(() -> sp), new S2CHitmarkerPacket(headshot, killed));
            sp.playNotifySound(headshot ? SoundEvents.EXPERIENCE_ORB_PICKUP : SoundEvents.ARROW_HIT_PLAYER,
                    SoundSource.PLAYERS, 0.7F, headshot ? 1.9F : 1.4F);
        }
        if (this.level() instanceof ServerLevel sl) {
            Vec3 h = res.getLocation();
            sl.sendParticles(headshot ? ParticleTypes.CRIT : ParticleTypes.DAMAGE_INDICATOR, h.x, h.y, h.z, headshot ? 12 : 5, 0.12, 0.12, 0.12, 0.22);
            sl.sendParticles(ParticleTypes.SMOKE, h.x, h.y, h.z, 3, 0.05, 0.05, 0.05, 0.05);
        }
        this.discard();
    }

    @Override
    protected void onHitBlock(BlockHitResult res) {
        super.onHitBlock(res);
        if (!this.level().isClientSide && this.level() instanceof ServerLevel sl) {
            Vec3 h = res.getLocation();
            BlockState st = sl.getBlockState(res.getBlockPos());
            sl.sendParticles(new BlockParticleOption(ParticleTypes.BLOCK, st), h.x, h.y, h.z, 10, 0.08, 0.08, 0.08, 0.18);
            sl.sendParticles(ParticleTypes.CRIT, h.x, h.y, h.z, 6, 0.05, 0.05, 0.05, 0.2);
            sl.sendParticles(ParticleTypes.SMOKE, h.x, h.y, h.z, 4, 0.04, 0.04, 0.04, 0.03);
            sl.playSound(null, h.x, h.y, h.z, st.getSoundType().getHitSound(), SoundSource.BLOCKS, 0.65F, 1.55F);
            ModNetwork.INSTANCE.send(
                    PacketDistributor.NEAR.with(() -> new PacketDistributor.TargetPoint(h.x, h.y, h.z, 96.0, sl.dimension())),
                    new S2CImpactPacket(h.x, h.y, h.z, res.getDirection().get3DDataValue())
            );
            this.discard();
        }
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/entity/RocketEntity.java"
package com.arsenalmod.entity;

import com.arsenalmod.registry.ModEntities;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.*;
import net.minecraft.world.entity.projectile.ThrowableProjectile;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.*;

public class RocketEntity extends ThrowableProjectile {
    private float dmg = 80.0F;
    public RocketEntity(EntityType<? extends RocketEntity> t, Level l) { super(t, l); }
    public RocketEntity(Level l, LivingEntity s, float dmg) { super(ModEntities.ROCKET.get(), s, l); this.dmg = dmg; }

    @Override protected void defineSynchedData() {}
    @Override protected float getGravity() { return 0.008F; }

    @Override
    public void tick() {
        super.tick();
        if (this.level().isClientSide) {
            Vec3 m = getDeltaMovement();
            for (int i = 0; i < 4; i++) {
                double f = i * 0.25;
                this.level().addParticle(ParticleTypes.FLAME, getX()-m.x*f, getY()-m.y*f, getZ()-m.z*f,
                        (random.nextDouble()-0.5)*0.07, (random.nextDouble()-0.5)*0.07, (random.nextDouble()-0.5)*0.07);
            }
            this.level().addParticle(ParticleTypes.CAMPFIRE_COSY_SMOKE, getX()-m.x*0.5, getY()-m.y*0.5, getZ()-m.z*0.5, 0, 0.03, 0);
        }
        if (this.tickCount > 120) boom();
    }

    private void boom() {
        if (!this.level().isClientSide) {
            if (this.level() instanceof ServerLevel sl) {
                sl.sendParticles(ParticleTypes.EXPLOSION_EMITTER, getX(), getY(), getZ(), 3, 0.5, 0.5, 0.5, 0);
                sl.sendParticles(ParticleTypes.FLAME, getX(), getY(), getZ(), 50, 1.2, 1.2, 1.2, 0.3);
                sl.sendParticles(ParticleTypes.LARGE_SMOKE, getX(), getY(), getZ(), 30, 1.0, 1.0, 1.0, 0.15);
            }
            this.level().explode(this, getX(), getY(), getZ(), 5.5F, Level.ExplosionInteraction.TNT);
            this.discard();
        }
    }

    @Override protected void onHitEntity(EntityHitResult r) {
        super.onHitEntity(r);
        if (r.getEntity() == getOwner()) return;
        if (!this.level().isClientSide) { r.getEntity().hurt(this.damageSources().thrown(this, getOwner()), dmg); boom(); }
    }
    @Override protected void onHitBlock(BlockHitResult r) { super.onHitBlock(r); boom(); }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/item/GunItem.java"
package com.arsenalmod.item;

import com.arsenalmod.client.GunAnimationEngine;
import com.arsenalmod.client.GunItemRenderer;
import com.arsenalmod.registry.ModItems;
import com.mojang.blaze3d.vertex.PoseStack;
import net.minecraft.ChatFormatting;
import net.minecraft.client.model.HumanoidModel;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.client.renderer.BlockEntityWithoutLevelRenderer;
import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.chat.Component;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.*;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.*;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraftforge.client.extensions.common.IClientItemExtensions;

import javax.annotation.Nullable;
import java.util.List;
import java.util.function.Consumer;

public class GunItem extends Item {
    public static final String TAG_AMMO = "Ammo", TAG_REL = "Rel", TAG_RS = "RS", TAG_RE = "RE", TAG_LAST = "Last";
    private final GunType type;

    public GunItem(GunType type) { super(new Item.Properties().stacksTo(1)); this.type = type; }
    public GunType getType() { return type; }

    public int getAmmo(ItemStack s) {
        CompoundTag t = s.getTag();
        return (t == null || !t.contains(TAG_AMMO)) ? type.maxAmmo : t.getInt(TAG_AMMO);
    }
    public void setAmmo(ItemStack s, int a) { s.getOrCreateTag().putInt(TAG_AMMO, Mth.clamp(a, 0, type.maxAmmo)); }
    public long getLastShot(ItemStack s) { return s.getTag() == null ? -1000L : s.getTag().getLong(TAG_LAST); }
    public void setLastShot(ItemStack s, long tick) { s.getOrCreateTag().putLong(TAG_LAST, tick); }

    public boolean isReloading(ItemStack s, long now) {
        CompoundTag t = s.getTag();
        return t != null && t.getBoolean(TAG_REL) && now <= t.getLong(TAG_RE) + 2L;
    }
    public float getReloadProgress(ItemStack s, long now, float pt) {
        CompoundTag t = s.getTag();
        if (t == null || !t.getBoolean(TAG_REL)) return 0F;
        long st = t.getLong(TAG_RS), en = t.getLong(TAG_RE);
        return en <= st ? 0F : Mth.clamp(((now + pt) - st) / (float)(en - st), 0F, 1F);
    }

    public boolean hasReserve(Player p) {
        if (p.isCreative()) return true;
        Item a = ModItems.getAmmoItem(type.ammoKind);
        for (ItemStack st : p.getInventory().items) if (st.is(a) && !st.isEmpty()) return true;
        return false;
    }

    public void startReload(ItemStack s, Player p) {
        long now = p.level().getGameTime();
        if (isReloading(s, now) || getAmmo(s) >= type.maxAmmo) return;
        if (!hasReserve(p)) {
            p.level().playSound(null, p.getX(), p.getY(), p.getZ(), SoundEvents.DISPENSER_FAIL, SoundSource.PLAYERS, 0.6F, 1.5F);
            return;
        }
        CompoundTag t = s.getOrCreateTag();
        t.putBoolean(TAG_REL, true); t.putLong(TAG_RS, now); t.putLong(TAG_RE, now + type.reloadTicks);
        p.level().playSound(null, p.getX(), p.getY(), p.getZ(), SoundEvents.IRON_TRAPDOOR_OPEN, SoundSource.PLAYERS, 0.5F, 1.85F);
    }

    @Override
    public void inventoryTick(ItemStack s, Level lvl, Entity e, int slot, boolean sel) {
        if (lvl.isClientSide || !(e instanceof Player p)) return;
        CompoundTag t = s.getTag();
        if (t == null) { setAmmo(s, type.maxAmmo); return; }
        if (t.getBoolean(TAG_REL)) {
            if (!sel) { t.putBoolean(TAG_REL, false); return; }
            if (lvl.getGameTime() >= t.getLong(TAG_RE)) {
                t.putBoolean(TAG_REL, false);
                if (p.isCreative()) setAmmo(s, type.maxAmmo);
                else {
                    int cur = getAmmo(s), need = type.maxAmmo - cur, got = 0;
                    Item a = ModItems.getAmmoItem(type.ammoKind);
                    for (ItemStack inv : p.getInventory().items) {
                        if (got >= need) break;
                        if (inv.is(a)) while (!inv.isEmpty() && got < need) { inv.shrink(1); got += type.roundsPerAmmoItem; }
                    }
                    setAmmo(s, Math.min(type.maxAmmo, cur + got));
                }
                lvl.playSound(null, p.getX(), p.getY(), p.getZ(), SoundEvents.PISTON_CONTRACT, SoundSource.PLAYERS, 0.55F, 1.9F);
            }
        }
    }

    @Override public boolean canAttackBlock(BlockState st, Level l, BlockPos pos, Player p) { return false; }
    @Override public boolean shouldCauseReequipAnimation(ItemStack o, ItemStack n, boolean sc) { return sc || o.getItem() != n.getItem(); }
    @Override public InteractionResultHolder<ItemStack> use(Level l, Player p, InteractionHand h) { return InteractionResultHolder.pass(p.getItemInHand(h)); }

    @Override
    public void appendHoverText(ItemStack s, @Nullable Level l, List<Component> tip, TooltipFlag f) {
        String dmg = type.pellets > 1 ? String.format("%.1f x%d", type.damage, type.pellets) : String.format("%.1f", type.damage);
        tip.add(Component.literal("Municao: " + getAmmo(s) + "/" + type.maxAmmo + " | Dano: " + dmg).withStyle(ChatFormatting.GOLD));
        tip.add(Component.literal("Perf. Armadura: " + Math.round(type.armorPen * 100) + "% | Headshot 2.2x").withStyle(ChatFormatting.RED));
        tip.add(Component.literal("[Esq] Atirar  [Dir] Mirar  [R] Recarregar").withStyle(ChatFormatting.AQUA));
    }

    @Override
    public void initializeClient(Consumer<IClientItemExtensions> c) {
        c.accept(new IClientItemExtensions() {
            private GunItemRenderer r;
            @Override public BlockEntityWithoutLevelRenderer getCustomRenderer() { return r == null ? (r = new GunItemRenderer()) : r; }
            @Override public boolean applyForgeHandTransform(PoseStack ps, LocalPlayer p, HumanoidArm arm, ItemStack s, float pt, float eq, float sw) {
                return GunAnimationEngine.applyFirstPersonTransform(ps, p, arm, s, pt, eq);
            }
            @Override public HumanoidModel.ArmPose getArmPose(LivingEntity e, InteractionHand h, ItemStack s) { return HumanoidModel.ArmPose.BOW_AND_ARROW; }
        });
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/item/GunType.java"
package com.arsenalmod.item;

public enum GunType {
    GLOCK19("glock19", "Glock 19", 12.0F, 0.22F, 5, 17, 32, false, 1, 1.1F, 6.0F,
            0.095F, 5.2F, 1.1F, 0.86F, false, false, false, AmmoKind.PISTOL, 17, 2.55F, -5.2F, 1.65F),
    AK47("ak47", "AK-47", 17.0F, 0.48F, 3, 30, 44, true, 1, 1.7F, 6.8F,
            0.135F, 4.6F, 1.25F, 0.76F, false, false, false, AmmoKind.RIFLE, 15, 2.90F, -16.0F, 0.95F),
    M4A1("m4a1", "M4A1 Tatica", 14.0F, 0.38F, 2, 30, 40, true, 1, 0.9F, 7.2F,
            0.085F, 2.8F, 0.72F, 0.70F, false, false, false, AmmoKind.RIFLE, 15, 3.55F, -17.0F, 1.05F),
    SPAS12("spas12", "SPAS-12", 6.5F, 0.20F, 15, 8, 48, false, 10, 6.2F, 5.4F,
            0.28F, 12.5F, 3.6F, 0.84F, false, false, true, AmmoKind.SHOTGUN, 1, 2.65F, -14.8F, 1.35F),
    AWP_SNIPER("awp_sniper", "AWP Sniper", 55.0F, 0.82F, 26, 5, 56, false, 1, 0.06F, 10.5F,
            0.30F, 15.0F, 4.2F, 0.22F, false, true, false, AmmoKind.SNIPER, 1, 3.70F, -21.5F, 1.35F),
    MINIGUN("minigun", "M134 Minigun", 11.0F, 0.45F, 1, 200, 68, true, 1, 2.9F, 6.8F,
            0.065F, 1.7F, 0.48F, 0.85F, false, false, false, AmmoKind.RIFLE, 40, 2.60F, -16.5F, 0.45F),
    RPG7("rpg7", "RPG-7", 80.0F, 0.95F, 28, 1, 60, false, 1, 0.28F, 2.8F,
            0.40F, 17.5F, 5.0F, 0.76F, true, false, false, AmmoKind.ROCKET, 1, 3.35F, -17.5F, 1.2F);

    public enum AmmoKind { PISTOL, RIFLE, SHOTGUN, SNIPER, ROCKET }

    public final String id, displayName;
    public final float damage, armorPen, spread, bulletSpeed, recoilKick, recoilPitch, cameraKick, adsFov;
    public final float sightVoxelsY, muzzleVoxelsZ, muzzleVoxelsY;
    public final int fireCooldown, maxAmmo, reloadTicks, pellets, roundsPerAmmoItem;
    public final boolean fullAuto, isRocket, isSniper, isShotgun;
    public final AmmoKind ammoKind;

    GunType(String id, String displayName, float damage, float armorPen, int fireCooldown, int maxAmmo,
            int reloadTicks, boolean fullAuto, int pellets, float spread, float bulletSpeed,
            float recoilKick, float recoilPitch, float cameraKick, float adsFov,
            boolean isRocket, boolean isSniper, boolean isShotgun, AmmoKind ammoKind,
            int roundsPerAmmoItem, float sightVoxelsY, float muzzleVoxelsZ, float muzzleVoxelsY) {
        this.id = id; this.displayName = displayName; this.damage = damage; this.armorPen = armorPen;
        this.fireCooldown = fireCooldown; this.maxAmmo = maxAmmo; this.reloadTicks = reloadTicks;
        this.fullAuto = fullAuto; this.pellets = pellets; this.spread = spread; this.bulletSpeed = bulletSpeed;
        this.recoilKick = recoilKick; this.recoilPitch = recoilPitch; this.cameraKick = cameraKick;
        this.adsFov = adsFov; this.isRocket = isRocket; this.isSniper = isSniper; this.isShotgun = isShotgun;
        this.ammoKind = ammoKind; this.roundsPerAmmoItem = roundsPerAmmoItem;
        this.sightVoxelsY = sightVoxelsY; this.muzzleVoxelsZ = muzzleVoxelsZ; this.muzzleVoxelsY = muzzleVoxelsY;
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/network/C2SReloadPacket.java"
package com.arsenalmod.network;

import com.arsenalmod.item.GunItem;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.network.NetworkEvent;
import java.util.function.Supplier;

public class C2SReloadPacket {
    public C2SReloadPacket() {}
    public static void encode(C2SReloadPacket m, FriendlyByteBuf b) {}
    public static C2SReloadPacket decode(FriendlyByteBuf b) { return new C2SReloadPacket(); }
    public static void handle(C2SReloadPacket m, Supplier<NetworkEvent.Context> ctx) {
        ServerPlayer p = ctx.get().getSender();
        if (p != null) { ItemStack s = p.getMainHandItem(); if (s.getItem() instanceof GunItem g) g.startReload(s, p); }
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/network/C2SShootPacket.java"
package com.arsenalmod.network;

import com.arsenalmod.entity.*;
import com.arsenalmod.item.*;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.*;
import net.minecraft.sounds.*;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.network.NetworkEvent;
import java.util.function.Supplier;

public class C2SShootPacket {
    private final boolean aiming;
    public C2SShootPacket(boolean aiming) { this.aiming = aiming; }
    public static void encode(C2SShootPacket m, FriendlyByteBuf b) { b.writeBoolean(m.aiming); }
    public static C2SShootPacket decode(FriendlyByteBuf b) { return new C2SShootPacket(b.readBoolean()); }

    public static void handle(C2SShootPacket msg, Supplier<NetworkEvent.Context> ctx) {
        ServerPlayer p = ctx.get().getSender();
        if (p == null) return;
        ItemStack st = p.getMainHandItem();
        if (!(st.getItem() instanceof GunItem gun)) return;

        ServerLevel lvl = p.serverLevel();
        long now = lvl.getGameTime();
        GunType t = gun.getType();
        if (gun.isReloading(st, now) || now - gun.getLastShot(st) < t.fireCooldown) return;
        int ammo = gun.getAmmo(st);
        if (ammo <= 0) { gun.startReload(st, p); return; }

        gun.setAmmo(st, ammo - 1);
        gun.setLastShot(st, now);

        Vec3 eye = p.getEyePosition(), look = p.getLookAngle();
        float spread = msg.aiming ? t.spread * 0.22F : t.spread;

        if (t.isRocket) {
            RocketEntity r = new RocketEntity(lvl, p, t.damage);
            Vec3 sp = eye.add(look.scale(0.9));
            r.setPos(sp.x, sp.y - 0.08, sp.z);
            r.shoot(look.x, look.y, look.z, t.bulletSpeed, spread);
            lvl.addFreshEntity(r);
        } else {
            for (int i = 0; i < t.pellets; i++) {
                BulletEntity b = new BulletEntity(lvl, p, t.damage, t.armorPen);
                Vec3 sp = eye.add(look.scale(0.55));
                b.setPos(sp.x, sp.y - 0.05, sp.z);
                b.shoot(look.x, look.y, look.z, t.bulletSpeed, spread);
                lvl.addFreshEntity(b);
            }
        }
        sound(lvl, p, t);
        Vec3 mz = eye.add(look.scale(1.15));
        lvl.sendParticles(ParticleTypes.SMOKE, mz.x, mz.y - 0.08, mz.z, t.isRocket ? 18 : 6, 0.09, 0.09, 0.09, 0.05);
        lvl.sendParticles(ParticleTypes.FLAME, mz.x, mz.y - 0.08, mz.z, t.isRocket ? 12 : 3, 0.05, 0.05, 0.05, 0.04);
    }

    private static void sound(ServerLevel l, ServerPlayer p, GunType t) {
        double x = p.getX(), y = p.getY(), z = p.getZ();
        switch (t) {
            case GLOCK19 -> { l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_BLAST,SoundSource.PLAYERS,1.0F,1.85F); l.playSound(null,x,y,z,SoundEvents.GENERIC_EXPLODE,SoundSource.PLAYERS,0.22F,2.0F); }
            case AK47 -> { l.playSound(null,x,y,z,SoundEvents.GENERIC_EXPLODE,SoundSource.PLAYERS,0.58F,1.32F); l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_BLAST,SoundSource.PLAYERS,1.1F,1.12F); }
            case M4A1 -> { l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_BLAST,SoundSource.PLAYERS,0.75F,1.72F); l.playSound(null,x,y,z,SoundEvents.IRON_TRAPDOOR_CLOSE,SoundSource.PLAYERS,0.55F,1.95F); }
            case SPAS12 -> { l.playSound(null,x,y,z,SoundEvents.GENERIC_EXPLODE,SoundSource.PLAYERS,1.0F,0.85F); l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_LARGE_BLAST,SoundSource.PLAYERS,1.15F,0.82F); }
            case AWP_SNIPER -> { l.playSound(null,x,y,z,SoundEvents.GENERIC_EXPLODE,SoundSource.PLAYERS,1.3F,0.70F); l.playSound(null,x,y,z,SoundEvents.LIGHTNING_BOLT_THUNDER,SoundSource.PLAYERS,0.38F,2.0F); }
            case MINIGUN -> { l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_BLAST,SoundSource.PLAYERS,0.75F,1.35F); l.playSound(null,x,y,z,SoundEvents.PISTON_EXTEND,SoundSource.PLAYERS,0.35F,2.0F); }
            case RPG7 -> { l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_LAUNCH,SoundSource.PLAYERS,1.6F,0.6F); l.playSound(null,x,y,z,SoundEvents.GENERIC_EXPLODE,SoundSource.PLAYERS,0.9F,0.65F); }
        }
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/network/ModNetwork.java"
package com.arsenalmod.network;

import com.arsenalmod.ArsenalMod;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.network.*;
import net.minecraftforge.network.simple.SimpleChannel;

public class ModNetwork {
    private static final String V = "2";
    public static final SimpleChannel INSTANCE = NetworkRegistry.newSimpleChannel(
            new ResourceLocation(ArsenalMod.MODID, "main"), () -> V, V::equals, V::equals);

    public static void register() {
        int id = 0;
        INSTANCE.messageBuilder(C2SShootPacket.class, id++, NetworkDirection.PLAY_TO_SERVER)
                .encoder(C2SShootPacket::encode).decoder(C2SShootPacket::decode).consumerMainThread(C2SShootPacket::handle).add();
        INSTANCE.messageBuilder(C2SReloadPacket.class, id++, NetworkDirection.PLAY_TO_SERVER)
                .encoder(C2SReloadPacket::encode).decoder(C2SReloadPacket::decode).consumerMainThread(C2SReloadPacket::handle).add();
        INSTANCE.messageBuilder(S2CImpactPacket.class, id++, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(S2CImpactPacket::encode).decoder(S2CImpactPacket::decode).consumerMainThread(S2CImpactPacket::handle).add();
        INSTANCE.messageBuilder(S2CHitmarkerPacket.class, id++, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(S2CHitmarkerPacket::encode).decoder(S2CHitmarkerPacket::decode).consumerMainThread(S2CHitmarkerPacket::handle).add();
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/network/S2CHitmarkerPacket.java"
package com.arsenalmod.network;

import com.arsenalmod.client.GunAnimationEngine;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.DistExecutor;
import net.minecraftforge.network.NetworkEvent;
import java.util.function.Supplier;

public class S2CHitmarkerPacket {
    public final boolean headshot, kill;
    public S2CHitmarkerPacket(boolean hs, boolean k) { this.headshot = hs; this.kill = k; }
    public static void encode(S2CHitmarkerPacket m, FriendlyByteBuf b) { b.writeBoolean(m.headshot); b.writeBoolean(m.kill); }
    public static S2CHitmarkerPacket decode(FriendlyByteBuf b) { return new S2CHitmarkerPacket(b.readBoolean(), b.readBoolean()); }
    public static void handle(S2CHitmarkerPacket m, Supplier<NetworkEvent.Context> ctx) {
        DistExecutor.unsafeRunWhenOn(Dist.CLIENT, () -> () -> GunAnimationEngine.triggerHitmarker(m.headshot, m.kill));
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/network/S2CImpactPacket.java"
package com.arsenalmod.network;

import com.arsenalmod.client.WorldEffectsRenderer;
import net.minecraft.core.Direction;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.DistExecutor;
import net.minecraftforge.network.NetworkEvent;
import java.util.function.Supplier;

public class S2CImpactPacket {
    public final double x, y, z;
    public final int dir;
    public S2CImpactPacket(double x, double y, double z, int dir) { this.x = x; this.y = y; this.z = z; this.dir = dir; }
    public static void encode(S2CImpactPacket m, FriendlyByteBuf b) { b.writeDouble(m.x); b.writeDouble(m.y); b.writeDouble(m.z); b.writeByte(m.dir); }
    public static S2CImpactPacket decode(FriendlyByteBuf b) { return new S2CImpactPacket(b.readDouble(), b.readDouble(), b.readDouble(), b.readByte()); }
    public static void handle(S2CImpactPacket m, Supplier<NetworkEvent.Context> ctx) {
        DistExecutor.unsafeRunWhenOn(Dist.CLIENT, () -> () -> WorldEffectsRenderer.addBulletHole(m.x, m.y, m.z, Direction.from3DDataValue(m.dir)));
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/registry/ModCreativeTabs.java"
package com.arsenalmod.registry;

import com.arsenalmod.ArsenalMod;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.*;
import net.minecraftforge.registries.*;

public class ModCreativeTabs {
    public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, ArsenalMod.MODID);
    public static final RegistryObject<CreativeModeTab> ARSENAL_TAB = TABS.register("arsenal_tab",
            () -> CreativeModeTab.builder()
                    .title(Component.translatable("itemGroup.arsenalmod.arsenal_tab"))
                    .icon(() -> new ItemStack(ModItems.AK47.get()))
                    .displayItems((p, out) -> {
                        out.accept(ModItems.GLOCK19.get()); out.accept(ModItems.AK47.get());
                        out.accept(ModItems.M4A1.get()); out.accept(ModItems.SPAS12.get());
                        out.accept(ModItems.AWP_SNIPER.get()); out.accept(ModItems.MINIGUN.get());
                        out.accept(ModItems.RPG7.get()); out.accept(ModItems.PISTOL_AMMO.get());
                        out.accept(ModItems.RIFLE_AMMO.get()); out.accept(ModItems.SHOTGUN_SHELL.get());
                        out.accept(ModItems.SNIPER_AMMO.get()); out.accept(ModItems.ROCKET_AMMO.get());
                    }).build());
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/registry/ModEntities.java"
package com.arsenalmod.registry;

import com.arsenalmod.ArsenalMod;
import com.arsenalmod.entity.*;
import net.minecraft.world.entity.*;
import net.minecraftforge.registries.*;

public class ModEntities {
    public static final DeferredRegister<EntityType<?>> ENTITIES = DeferredRegister.create(ForgeRegistries.ENTITY_TYPES, ArsenalMod.MODID);
    public static final RegistryObject<EntityType<BulletEntity>> BULLET = ENTITIES.register("bullet",
            () -> EntityType.Builder.<BulletEntity>of(BulletEntity::new, MobCategory.MISC).sized(0.14F, 0.14F).clientTrackingRange(8).updateInterval(1).build("bullet"));
    public static final RegistryObject<EntityType<RocketEntity>> ROCKET = ENTITIES.register("rocket",
            () -> EntityType.Builder.<RocketEntity>of(RocketEntity::new, MobCategory.MISC).sized(0.42F, 0.42F).clientTrackingRange(10).updateInterval(1).build("rocket"));
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/java/com/arsenalmod/registry/ModItems.java"
package com.arsenalmod.registry;

import com.arsenalmod.ArsenalMod;
import com.arsenalmod.item.*;
import net.minecraft.world.item.Item;
import net.minecraftforge.registries.*;

public class ModItems {
    public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, ArsenalMod.MODID);
    public static final RegistryObject<Item> GLOCK19 = ITEMS.register("glock19", () -> new GunItem(GunType.GLOCK19));
    public static final RegistryObject<Item> AK47 = ITEMS.register("ak47", () -> new GunItem(GunType.AK47));
    public static final RegistryObject<Item> M4A1 = ITEMS.register("m4a1", () -> new GunItem(GunType.M4A1));
    public static final RegistryObject<Item> SPAS12 = ITEMS.register("spas12", () -> new GunItem(GunType.SPAS12));
    public static final RegistryObject<Item> AWP_SNIPER = ITEMS.register("awp_sniper", () -> new GunItem(GunType.AWP_SNIPER));
    public static final RegistryObject<Item> MINIGUN = ITEMS.register("minigun", () -> new GunItem(GunType.MINIGUN));
    public static final RegistryObject<Item> RPG7 = ITEMS.register("rpg7", () -> new GunItem(GunType.RPG7));
    public static final RegistryObject<Item> PISTOL_AMMO = ITEMS.register("pistol_ammo", () -> new Item(new Item.Properties()));
    public static final RegistryObject<Item> RIFLE_AMMO = ITEMS.register("rifle_ammo", () -> new Item(new Item.Properties()));
    public static final RegistryObject<Item> SHOTGUN_SHELL = ITEMS.register("shotgun_shell", () -> new Item(new Item.Properties()));
    public static final RegistryObject<Item> SNIPER_AMMO = ITEMS.register("sniper_ammo", () -> new Item(new Item.Properties()));
    public static final RegistryObject<Item> ROCKET_AMMO = ITEMS.register("rocket_ammo", () -> new Item(new Item.Properties().stacksTo(16)));

    public static Item getAmmoItem(GunType.AmmoKind k) {
        return switch (k) {
            case PISTOL -> PISTOL_AMMO.get();
            case RIFLE -> RIFLE_AMMO.get();
            case SHOTGUN -> SHOTGUN_SHELL.get();
            case SNIPER -> SNIPER_AMMO.get();
            case ROCKET -> ROCKET_AMMO.get();
        };
    }
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/META-INF/mods.toml"
modLoader="javafml"
loaderVersion="[47,)"
license="MIT"
[[mods]]
modId="arsenalmod"
version="2.0.0"
displayName="Arsenal 3D Realista"
description='''Armas 3D detalhadas, maos animadas, marcas de bala nos blocos, estojos voando e balistica realista.'''
[[dependencies.arsenalmod]]
modId="forge"
mandatory=true
versionRange="[47,)"
ordering="NONE"
side="BOTH"
[[dependencies.arsenalmod]]
modId="minecraft"
mandatory=true
versionRange="[1.20.1,1.21)"
ordering="NONE"
side="BOTH"
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/lang/en_us.json"
{
  "itemGroup.arsenalmod.arsenal_tab": "Arsenal 3D - Armas",
  "item.arsenalmod.glock19": "Glock 19 (9mm)",
  "item.arsenalmod.ak47": "AK-47 (7.62mm)",
  "item.arsenalmod.m4a1": "M4A1 Tatica (5.56mm)",
  "item.arsenalmod.spas12": "SPAS-12 (Cal. 12)",
  "item.arsenalmod.awp_sniper": "AWP Sniper (.338)",
  "item.arsenalmod.minigun": "M134 Minigun",
  "item.arsenalmod.rpg7": "RPG-7 (HEAT)",
  "item.arsenalmod.pistol_ammo": "Municao 9mm",
  "item.arsenalmod.rifle_ammo": "Municao de Fuzil",
  "item.arsenalmod.shotgun_shell": "Cartucho Calibre 12",
  "item.arsenalmod.sniper_ammo": "Municao .338 Lapua",
  "item.arsenalmod.rocket_ammo": "Foguete PG-7V",
  "key.categories.arsenalmod": "Arsenal 3D",
  "key.arsenalmod.reload": "Recarregar Arma"
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/lang/pt_br.json"
{
  "itemGroup.arsenalmod.arsenal_tab": "Arsenal 3D - Armas",
  "item.arsenalmod.glock19": "Glock 19 (9mm)",
  "item.arsenalmod.ak47": "AK-47 (7.62mm)",
  "item.arsenalmod.m4a1": "M4A1 Tatica (5.56mm)",
  "item.arsenalmod.spas12": "SPAS-12 (Cal. 12)",
  "item.arsenalmod.awp_sniper": "AWP Sniper (.338)",
  "item.arsenalmod.minigun": "M134 Minigun",
  "item.arsenalmod.rpg7": "RPG-7 (HEAT)",
  "item.arsenalmod.pistol_ammo": "Municao 9mm",
  "item.arsenalmod.rifle_ammo": "Municao de Fuzil",
  "item.arsenalmod.shotgun_shell": "Cartucho Calibre 12",
  "item.arsenalmod.sniper_ammo": "Municao .338 Lapua",
  "item.arsenalmod.rocket_ammo": "Foguete PG-7V",
  "key.categories.arsenalmod": "Arsenal 3D",
  "key.arsenalmod.reload": "Recarregar Arma"
}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/ak47.json"
{"parent":"builtin/entity","gui_light":"front","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/awp_sniper.json"
{"parent":"builtin/entity","gui_light":"front","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/glock19.json"
{"parent":"builtin/entity","gui_light":"front","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/m4a1.json"
{"parent":"builtin/entity","gui_light":"front","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/minigun.json"
{"parent":"builtin/entity","gui_light":"front","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/pistol_ammo.json"
{"parent":"minecraft:item/generated","textures":{"layer0":"arsenalmod:item/pistol_ammo"}}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/rifle_ammo.json"
{"parent":"minecraft:item/generated","textures":{"layer0":"arsenalmod:item/rifle_ammo"}}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/rocket_ammo.json"
{"parent":"minecraft:item/generated","textures":{"layer0":"arsenalmod:item/rocket_ammo"}}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/rpg7.json"
{"parent":"builtin/entity","gui_light":"front","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/shotgun_shell.json"
{"parent":"minecraft:item/generated","textures":{"layer0":"arsenalmod:item/shotgun_shell"}}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/sniper_ammo.json"
{"parent":"minecraft:item/generated","textures":{"layer0":"arsenalmod:item/sniper_ammo"}}
ARSENAL_V2_EOF

cat << 'ARSENAL_V2_EOF' > "src/main/resources/assets/arsenalmod/models/item/spas12.json"
{"parent":"builtin/entity","gui_light":"front","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V2_EOF


echo "[4/5] Gerando atlas 3D (20 materiais), bullet_hole.png e icones de municao..."
cat << 'TEX_V2_EOF' > GenTexturesV2.java
import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.File;
import java.util.Random;

public class GenTexturesV2 {
    static int clamp(int v) { return Math.max(0, Math.min(255, v)); }
    static int argb(int a, int r, int g, int b) {
        return (clamp(a) << 24) | (clamp(r) << 16) | (clamp(g) << 8) | clamp(b);
    }

    public static void main(String[] args) throws Exception {
        // 1. 20-Tile 256x256 weapons_atlas.png
        BufferedImage atlas = new BufferedImage(256, 256, BufferedImage.TYPE_INT_ARGB);
        Random rng = new Random(2026L);

        for (int tile = 0; tile < 20; tile++) {
            int ox = (tile % 8) * 32;
            int oy = (tile / 8) * 32;
            for (int y = 0; y < 32; y++) {
                for (int x = 0; x < 32; x++) {
                    int n = rng.nextInt(15) - 7;
                    int c;
                    switch (tile) {
                        case 0 -> {
                            int v = 40 + n + (y % 4 == 0 ? 5 : 0) - ((x == 0 || y == 0 || x == 31 || y == 31) ? 9 : 0);
                            c = argb(255, v, v + 2, v + 6);
                        }
                        case 1 -> {
                            int v = 82 + n + (x % 3 == 0 ? 6 : 0);
                            c = argb(255, v, v + 3, v + 8);
                        }
                        case 2 -> {
                            int sheen = (int) (30 * Math.abs(((x + y) % 32) / 16.0 - 1.0));
                            int v = 166 + n + sheen;
                            c = argb(255, v, v + 4, v + 10);
                        }
                        case 3 -> {
                            int v = 26 + n + ((x + y) % 2 == 0 ? 3 : 0);
                            c = argb(255, v, v + 1, v + 3);
                        }
                        case 4 -> {
                            boolean d = ((x + y) % 4 == 0) || ((x - y + 32) % 4 == 0);
                            int v = (d ? 48 : 22) + n / 2;
                            c = argb(255, v, v, v + 2);
                        }
                        case 5 -> {
                            int v = ((y % 6) < 2 ? 20 : 62) + n / 2;
                            c = argb(255, v, v + 2, v + 5);
                        }
                        case 6 -> {
                            int w = ((y + (x / 4)) % 6 < 3) ? 13 : 0;
                            c = argb(255, 142 + w + n, 74 + w / 2 + n, 30 + n / 2);
                        }
                        case 7 -> {
                            int w = ((y + (x / 5)) % 5 < 2) ? 10 : 0;
                            c = argb(255, 74 + w + n, 42 + w / 2 + n, 22 + n / 2);
                        }
                        case 8 -> c = argb(255, 74 + n, 90 + n, 52 + n);
                        case 9 -> c = argb(255, 180 + n, 154 + n, 114 + n);
                        case 10 -> {
                            int sheen = (int) (28 * Math.abs(x / 16.0 - 1.0));
                            c = argb(255, 208 + sheen + n, 170 + sheen + n, 62 + n);
                        }
                        case 11 -> {
                            int dx = x - 16, dy = y - 16;
                            if ((x - 10) * (x - 10) + (y - 10) * (y - 10) < 16) c = argb(255, 185, 236, 255);
                            else if (dx * dx + dy * dy < 145) c = argb(255, 24, 88, 165);
                            else c = argb(255, 16, 34, 70);
                        }
                        case 12 -> {
                            int b = Math.max(0, 48 - (Math.abs(x - 16) + Math.abs(y - 16)) * 2);
                            c = argb(255, 255, 32 + b, 32 + b);
                        }
                        case 13 -> {
                            int b = Math.max(0, 48 - (Math.abs(x - 16) + Math.abs(y - 16)) * 2);
                            c = argb(255, 38 + b, 255, 86 + b);
                        }
                        case 14 -> {
                            int d = Math.abs(x - 16) + Math.abs(y - 16);
                            if (d < 12) c = argb(255, 255, 252, 215);
                            else if (d < 22) c = argb(255, 255, 198, 52);
                            else c = argb(255, 255, 115, 20);
                        }
                        case 15 -> {
                            int rib = (x % 4 == 0) ? 10 : 0;
                            c = argb(255, 188 + rib + n, 28 + n / 2, 28 + n / 2);
                        }
                        case 16 -> {
                            int st = ((y == 4 || y == 27) && (x % 3 != 0)) ? 8 : 0;
                            int v = 34 + n / 2 + st;
                            c = argb(255, v + 2, v + 1, v);
                        }
                        case 17 -> {
                            int p = ((x / 8) + (y / 6)) % 3;
                            if (p == 0) c = argb(255, 46 + n / 2, 54 + n / 2, 44 + n / 2);
                            else if (p == 1) c = argb(255, 34 + n / 2, 40 + n / 2, 36 + n / 2);
                            else c = argb(255, 58 + n / 2, 62 + n / 2, 50 + n / 2);
                        }
                        case 18 -> {
                            int cell = ((x / 2) + (y / 2)) % 2;
                            int v = (cell == 0 ? 48 : 24) + n / 3;
                            c = argb(255, v, v + 1, v + 3);
                        }
                        default -> {
                            int cx = (x % 8) - 4, cy = (y % 8) - 4;
                            if (cx * cx + cy * cy <= 5) c = argb(255, 12, 13, 16);
                            else {
                                int v = 56 + n;
                                c = argb(255, v, v + 2, v + 5);
                            }
                        }
                    }
                    atlas.setRGB(ox + x, oy + y, c);
                }
            }
        }
        File entDir = new File("src/main/resources/assets/arsenalmod/textures/entity");
        entDir.mkdirs();
        ImageIO.write(atlas, "PNG", new File(entDir, "weapons_atlas.png"));

        // 2. 32x32 bullet_hole.png
        BufferedImage hole = new BufferedImage(32, 32, BufferedImage.TYPE_INT_ARGB);
        Random hrng = new Random(777L);
        for (int y = 0; y < 32; y++) {
            for (int x = 0; x < 32; x++) {
                double dx = x - 15.5, dy = y - 15.5;
                double dist = Math.hypot(dx, dy);
                double ang = Math.atan2(dy, dx);
                double ray = Math.pow(Math.abs(Math.sin(ang * 5.0 + 0.6)), 10)
                           + Math.pow(Math.abs(Math.cos(ang * 3.0 - 0.4)), 12);
                double r = dist + (hrng.nextDouble() * 1.6 - 0.8);
                int c = 0;
                if (r < 4.2) {
                    int v = 8 + hrng.nextInt(9);
                    c = argb(245, v, v, v);
                } else if (r < 6.8) {
                    int v = 42 + hrng.nextInt(25) - 10;
                    c = argb(220, v, v, v);
                } else if (r < 11.5) {
                    if (ray > 0.65) {
                        int v = 24 + hrng.nextInt(13);
                        c = argb(195, v, v, v);
                    } else {
                        int a = (int) ((1.0 - (r - 6.8) / 4.7) * 145.0);
                        int v = 32 + hrng.nextInt(17) - 8;
                        c = argb(a, v, v, v);
                    }
                } else if (ray > 0.78 && r < 14.8) {
                    int a = (int) ((1.0 - (r - 11.5) / 3.5) * 160.0);
                    int v = 35 + hrng.nextInt(16);
                    c = argb(a, v, v, v);
                }
                hole.setRGB(x, y, c);
            }
        }
        ImageIO.write(hole, "PNG", new File(entDir, "bullet_hole.png"));

        // 3. 16x16 Ammo Icons
        String itemDir = "src/main/resources/assets/arsenalmod/textures/item/";
        new File(itemDir).mkdirs();

        BufferedImage pi = new BufferedImage(16, 16, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = pi.createGraphics();
        for (int ox : new int[]{4, 9}) {
            g.setColor(new Color(208, 168, 62)); g.fillRect(ox, 7, 3, 7);
            g.setColor(new Color(160, 122, 40)); g.fillRect(ox, 13, 3, 2);
            g.setColor(new Color(196, 116, 56)); g.fillRect(ox, 4, 3, 3);
            g.setColor(new Color(224, 144, 78)); g.fillRect(ox + 1, 3, 1, 1);
            g.setColor(new Color(238, 206, 108)); g.fillRect(ox, 7, 1, 6);
        }
        g.dispose();
        ImageIO.write(pi, "PNG", new File(itemDir + "pistol_ammo.png"));

        BufferedImage ri = new BufferedImage(16, 16, BufferedImage.TYPE_INT_ARGB);
        g = ri.createGraphics();
        for (int ox : new int[]{3, 7, 11}) {
            g.setColor(new Color(204, 164, 58)); g.fillRect(ox, 6, 3, 9);
            g.setColor(new Color(236, 204, 106)); g.fillRect(ox, 6, 1, 8);
            g.setColor(new Color(195, 110, 50)); g.fillRect(ox + 1, 2, 1, 4);
            g.setColor(new Color(225, 140, 72)); g.fillRect(ox + 1, 1, 1, 1);
        }
        g.dispose();
        ImageIO.write(ri, "PNG", new File(itemDir + "rifle_ammo.png"));

        BufferedImage si = new BufferedImage(16, 16, BufferedImage.TYPE_INT_ARGB);
        g = si.createGraphics();
        for (int ox : new int[]{3, 9}) {
            g.setColor(new Color(196, 36, 36)); g.fillRect(ox, 3, 4, 8);
            g.setColor(new Color(232, 74, 74)); g.fillRect(ox, 3, 1, 8);
            g.setColor(new Color(214, 174, 62)); g.fillRect(ox, 11, 4, 4);
            g.setColor(new Color(244, 212, 112)); g.fillRect(ox, 11, 1, 4);
        }
        g.dispose();
        ImageIO.write(si, "PNG", new File(itemDir + "shotgun_shell.png"));

        BufferedImage sni = new BufferedImage(16, 16, BufferedImage.TYPE_INT_ARGB);
        g = sni.createGraphics();
        g.setColor(new Color(210, 170, 62)); g.fillRect(6, 6, 4, 9);
        g.setColor(new Color(242, 212, 116)); g.fillRect(6, 6, 1, 8);
        g.setColor(new Color(150, 114, 34)); g.fillRect(6, 14, 4, 2);
        g.setColor(new Color(196, 112, 48)); g.fillRect(7, 2, 2, 4);
        g.setColor(new Color(232, 148, 76)); g.fillRect(7, 1, 2, 1);
        g.dispose();
        ImageIO.write(sni, "PNG", new File(itemDir + "sniper_ammo.png"));

        BufferedImage rki = new BufferedImage(16, 16, BufferedImage.TYPE_INT_ARGB);
        g = rki.createGraphics();
        g.setColor(new Color(110, 116, 122)); g.fillRect(7, 9, 2, 6);
        g.setColor(new Color(70, 76, 82)); g.fillRect(5, 13, 6, 2);
        g.setColor(new Color(82, 98, 58)); g.fillRect(5, 4, 6, 5);
        g.setColor(new Color(212, 174, 64)); g.fillRect(5, 6, 6, 1);
        g.setColor(new Color(96, 114, 68)); g.fillRect(6, 2, 4, 2);
        g.setColor(new Color(212, 174, 64)); g.fillRect(7, 1, 2, 1);
        g.dispose();
        ImageIO.write(rki, "PNG", new File(itemDir + "rocket_ammo.png"));
    }
}

TEX_V2_EOF
javac GenTexturesV2.java
java -Djava.awt.headless=true GenTexturesV2
rm -f GenTexturesV2.java GenTexturesV2.class

echo "[5/5] Compilando Arsenal 3D v2.0 para .jar (Forge 1.20.1)..."
"$GBIN" build --no-daemon --stacktrace

JAR_FILE="$(ls build/libs/arsenalmod-*.jar | grep -v sources | head -n 1)"
cp "$JAR_FILE" "$BASE_DIR/arsenalmod-2.0.0-forge-1.20.1.jar"

echo "=========================================================="
echo "  SUCESSO! ARSENAL 3D v2.0 COMPILADO SEM ERROS!"
echo "  Arquivo .jar pronto em:"
echo "  $BASE_DIR/arsenalmod-2.0.0-forge-1.20.1.jar"
echo "=========================================================="
