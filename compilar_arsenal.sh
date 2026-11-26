#!/usr/bin/env bash
set -e
echo "=========================================================="
echo "   ARSENAL 3D v3.0 (REFORMULADO) - 1.20.1 FORGE           "
echo "=========================================================="

IS_TERMUX=0
if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ]; then IS_TERMUX=1; fi

if [ "$IS_TERMUX" -eq 1 ]; then
    echo "[1/5] Preparando Java 17 no Termux..."
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
W="$PWD/arsenalmod_v3"
rm -rf "$W" && mkdir -p "$W" && cd "$W"
mkdir -p src/main/java/com/arsenalmod/{item,registry,entity,network,client}
mkdir -p src/main/resources/META-INF src/main/resources/assets/arsenalmod/{lang,models/item,textures/item,textures/entity}

echo "[3/5] Gerando modelos 3D esguios, animacoes e particulas proprias..."

cat << EOF > gradle.properties
org.gradle.jvmargs=${HEAP}
org.gradle.daemon=false
org.gradle.parallel=false
EOF

cat << 'ARSENAL_V3_EOF' > "build.gradle"
plugins {
    id 'java'
    id 'net.minecraftforge.gradle' version '6.0.24'
}
group = 'com.arsenalmod'
version = '3.0.0'
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
            'Specification-Version'  : '3',
            'Implementation-Title'   : project.name,
            'Implementation-Version' : project.version,
            'Implementation-Vendor'  : 'arsenalmod'
        ])
    }
    finalizedBy 'reobfJar'
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "settings.gradle"
pluginManagement {
    repositories {
        gradlePluginPortal()
        maven { name = 'MinecraftForge'; url = 'https://maven.minecraftforge.net/' }
    }
}
rootProject.name = 'arsenalmod'
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/ArsenalMod.java"
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
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/client/BulletRenderer.java"
package com.arsenalmod.client;

import com.arsenalmod.entity.BulletEntity;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.entity.*;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.phys.Vec3;

public class BulletRenderer extends EntityRenderer<BulletEntity> {
    public BulletRenderer(EntityRendererProvider.Context c) { super(c); }
    @Override public ResourceLocation getTextureLocation(BulletEntity e) { return GunModelGeometry.ATLAS; }
    @Override
    public void render(BulletEntity e, float yaw, float pt, PoseStack ps, MultiBufferSource buf, int light) {
        Vec3 v = e.getDeltaMovement();
        if (v.lengthSqr() < 1e-6) return;
        double hz = Math.sqrt(v.x * v.x + v.z * v.z);
        ps.pushPose();
        ps.mulPose(Axis.YP.rotationDegrees((float)(Math.atan2(v.x, v.z) * 180.0 / Math.PI)));
        ps.mulPose(Axis.XP.rotationDegrees(-(float)(Math.atan2(v.y, hz) * 180.0 / Math.PI)));
        GunModelGeometry.renderBullet3D(ps, buf);
        ps.popPose();
    }
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/client/GunAnimationEngine.java"
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
    public static float recZ = 0F, recPitch = 0F, recRoll = 0F;
    public static float slide = 0F, flash = 0F, flashAngle = 0F;
    public static float pumpTimer = 0F, boltTimer = 0F, spinAngle = 0F, spinSpeed = 0F;
    public static float swayX = 0F, swayY = 0F, prevYaw = 0F, prevPitch = 0F, landDip = 0F;
    private static boolean wasOnGround = true;

    // Live choreographed part tracks (in 1/32 sub-voxels)
    public static float magY = 0F, magZ = 0F, magRot = 0F;
    public static boolean magVisible = true;
    public static float relBolt = 0F, whSlide = 0F, whRot = 0F;
    public static float lhX = 0F, lhY = 0F, lhZ = 0F, lhRotX = 0F;
    public static float rhBolt = 0F;
    public static float shellFeed = 0F; // SPAS-12 visible shell loading!

    public static float hitTimer = 0F;
    public static boolean hitHead = false, hitKill = false;
    private static long lastNano = System.nanoTime();
    private static int lastStage = 0;
    private static boolean shellEjectedForCycle = false;

    public static void triggerHitmarker(boolean hs, boolean k) { hitTimer = 0.25F; hitHead = hs; hitKill = k; }

    public static void onLocalShot(GunType t, LocalPlayer p) {
        float aim = isAiming ? 0.45F : 1.0F;
        recZ = Math.min(0.18F, recZ + t.recoilKick * aim);
        recPitch = Math.min(20F, recPitch + t.recoilPitch * aim);
        recRoll = (float)((Math.random() - 0.5) * 6.0F * aim);
        slide = 1.0F; flash = 1.0F; flashAngle = (float)(Math.random() * 360.0);

        if (t == GunType.SPAS12) { pumpTimer = 0.56F; shellEjectedForCycle = false; }
        else if (t == GunType.AWP_SNIPER) { boltTimer = 0.92F; shellEjectedForCycle = false; }
        else if (t == GunType.MINIGUN) spinSpeed = Math.min(1350F, spinSpeed + 420F);

        if (p != null) {
            float ck = t.cameraKick * (isAiming ? 0.5F : 1.0F);
            p.setXRot(Mth.clamp(p.getXRot() - ck, -89.5F, 89.5F));
            p.setYRot(p.getYRot() + (float)((Math.random() - 0.5) * ck * 0.5F));

            if (!t.isRocket && !t.isShotgun && !t.isSniper) ejectShell(p, false);
            if (!t.isRocket) {
                Vec3 eye = p.getEyePosition(), look = p.getLookAngle();
                Vec3 right = look.cross(new Vec3(0, 1, 0)).normalize(), up = right.cross(look).normalize();
                Vec3 mz = eye.add(look.scale(0.85)).add(right.scale(isAiming ? 0.0 : 0.14)).add(up.scale(isAiming ? -0.02 : -0.09));
                WorldEffectsRenderer.spawnTracer(mz, eye.add(look.scale(35.0)));
            }
        }
    }

    private static void ejectShell(LocalPlayer p, boolean shotgun) {
        Vec3 eye = p.getEyePosition(), look = p.getLookAngle();
        Vec3 right = look.cross(new Vec3(0, 1, 0)).normalize(), up = right.cross(look).normalize();
        Vec3 port = eye.add(look.scale(0.42)).add(right.scale(isAiming ? 0.08 : 0.22)).add(up.scale(-0.12));
        WorldEffectsRenderer.spawnShell(port, right, up, look, shotgun);
    }

    public static void updateFrame() {
        long now = System.nanoTime();
        float dt = Math.min(0.05F, (now - lastNano) / 1_000_000_000.0F);
        lastNano = now;

        Minecraft mc = Minecraft.getInstance();
        LocalPlayer p = mc.player;
        boolean held = p != null && p.getMainHandItem().getItem() instanceof GunItem;
        boolean rel = false;
        if (held) {
            ItemStack st = p.getMainHandItem();
            rel = ((GunItem)st.getItem()).isReloading(st, p.level().getGameTime());
            float dy = Mth.wrapDegrees(p.getYRot() - prevYaw), dp = p.getXRot() - prevPitch;
            prevYaw = p.getYRot(); prevPitch = p.getXRot();
            swayX = Mth.clamp(swayX - dy * 0.004F, -0.065F, 0.065F);
            swayY = Mth.clamp(swayY + dp * 0.004F, -0.055F, 0.055F);
            if (!wasOnGround && p.onGround()) landDip = 0.055F;
            wasOnGround = p.onGround();
        } else { isAiming = false; }

        swayX *= (float)Math.exp(-dt * 10F);
        swayY *= (float)Math.exp(-dt * 10F);
        landDip *= (float)Math.exp(-dt * 11F);
        hitTimer = Math.max(0F, hitTimer - dt);

        ads += (((held && isAiming && !rel) ? 1F : 0F) - ads) * Math.min(1F, dt * 15F);
        boolean spr = held && p.isSprinting() && !isAiming && !rel && recZ < 0.025F;
        sprint += ((spr ? 1F : 0F) - sprint) * Math.min(1F, dt * 9.5F);

        recZ *= (float)Math.exp(-dt * 14F);
        recPitch *= (float)Math.exp(-dt * 12.5F);
        recRoll *= (float)Math.exp(-dt * 12F);
        slide *= (float)Math.exp(-dt * 24F);
        flash = Math.max(0F, flash - dt * 22F);

        if (pumpTimer > 0F) {
            float pr = pumpTimer; pumpTimer = Math.max(0F, pumpTimer - dt);
            if (pr > 0.36F && pumpTimer <= 0.36F && p != null) {
                p.playSound(SoundEvents.PISTON_EXTEND, 0.45F, 1.65F);
                if (!shellEjectedForCycle) { ejectShell(p, true); shellEjectedForCycle = true; }
            }
            if (pr > 0.14F && pumpTimer <= 0.14F && p != null) p.playSound(SoundEvents.PISTON_CONTRACT, 0.45F, 1.9F);
        }
        if (boltTimer > 0F) {
            float pr = boltTimer; boltTimer = Math.max(0F, boltTimer - dt);
            if (pr > 0.60F && boltTimer <= 0.60F && p != null) {
                p.playSound(SoundEvents.IRON_TRAPDOOR_OPEN, 0.45F, 1.95F);
                if (!shellEjectedForCycle) { ejectShell(p, false); shellEjectedForCycle = true; }
            }
            if (pr > 0.24F && boltTimer <= 0.24F && p != null) p.playSound(SoundEvents.IRON_TRAPDOOR_CLOSE, 0.45F, 1.8F);
        }
        spinAngle = (spinAngle + spinSpeed * dt) % 360F;
        spinSpeed *= (float)Math.exp(-dt * 3.0F);
    }

    private static float ease(float t) { t = Mth.clamp(t, 0F, 1F); return t * t * (3F - 2F * t); }
    public static float getPump() { return (pumpTimer <= 0F || pumpTimer > 0.44F) ? 0F : Mth.sin((1F - pumpTimer / 0.44F) * (float)Math.PI); }
    public static float getBolt() { return (boltTimer <= 0F || boltTimer > 0.78F) ? 0F : Mth.sin((1F - boltTimer / 0.78F) * (float)Math.PI); }

    public static boolean applyFirstPersonTransform(PoseStack ps, LocalPlayer p, HumanoidArm arm,
                                                    ItemStack stack, float pt, float equip) {
        if (!(stack.getItem() instanceof GunItem gun)) return false;
        GunType t = gun.getType();
        int side = (arm == HumanoidArm.RIGHT) ? 1 : -1;
        long gt = p.level().getGameTime();
        boolean reloading = gun.isReloading(stack, gt);
        float rel = reloading ? gun.getReloadProgress(stack, gt, pt) : 0F;

        float a = ease(ads);
        float adsX = (t == GunType.MINIGUN ? 0.14F * side : 0F);
        float adsY = -(t.sightU / 32.0F);

        float x = Mth.lerp(a, t.hipX * side, adsX);
        float y = Mth.lerp(a, t.hipY, adsY);
        float z = Mth.lerp(a, t.hipZ, t.adsZ);

        float time = (gt + pt) * 0.085F;
        float sw = 1F - a * 0.88F;
        float wd = Mth.lerp(pt, p.walkDistO, p.walkDist);
        float wb = Mth.lerp(pt, p.oBob, p.bob);

        x += (swayX + Mth.cos(time * 0.8F) * 0.003F + Mth.cos(wd * (float)Math.PI) * wb * 0.14F) * sw;
        y += (swayY - landDip + Mth.sin(time * 1.6F) * 0.003F - Math.abs(Mth.sin(wd * (float)Math.PI)) * wb * 0.16F) * sw;
        y -= ease(equip) * 0.42F;

        z += recZ; y += recZ * 0.12F;

        // Reset choreographed part states
        magY = 0F; magZ = 0F; magRot = 0F; magVisible = true;
        relBolt = 0F; whSlide = 0F; whRot = 0F;
        lhX = 0F; lhY = 0F; lhZ = 0F; lhRotX = 0F;
        rhBolt = getBolt(); shellFeed = 0F;

        float rX = 0F, rY = 0F, rZ = 0F, oX = 0F, oY = 0F, oZ = 0F;

        if (reloading) {
            int stg = rel < 0.20F ? 1 : (rel < 0.66F ? 2 : (rel < 0.84F ? 3 : 4));
            if (stg != lastStage) {
                if (stg == 3) p.playSound(SoundEvents.IRON_TRAPDOOR_CLOSE, 0.55F, t.isRocket ? 0.9F : 1.75F);
                if (stg == 4) p.playSound(SoundEvents.PISTON_EXTEND, 0.45F, t.isRocket ? 1.1F : 1.9F);
                lastStage = stg;
            }

            if (t == GunType.RPG7) {
                // Authentic RPG-7 Front-Loading Reload (angles tube cleanly forward-left so you watch warhead load!)
                float env = rel < 0.16F ? ease(rel / 0.16F) : (rel > 0.86F ? ease((1F - rel) / 0.14F) : 1F);
                oX = -0.14F * env * side; oY = -0.10F * env; oZ = -0.16F * env;
                rX = 22F * env; rY = 34F * env * side; rZ = -18F * env * side;
                if (rel < 0.24F) {
                    whSlide = 1.0F;
                    float f = ease(rel / 0.24F);
                    lhY = -10F * f; lhZ = -10F * f;
                } else if (rel < 0.68F) {
                    float f = ease((rel - 0.24F) / 0.44F);
                    whSlide = 1.0F - f;
                    lhX = 1.5F; lhY = 2.8F; lhZ = -19F - whSlide * 14F;
                } else if (rel < 0.84F) {
                    float f = ease((rel - 0.68F) / 0.16F);
                    whSlide = 0F; whRot = f * 90F;
                    float thump = Mth.sin(f * (float)Math.PI);
                    oZ += thump * 0.055F;
                    lhX = 1.5F * (1F - f); lhY = 2.8F * (1F - f); lhZ = -19F * (1F - f);
                }
            } else if (t == GunType.SPAS12) {
                // SPAS-12 Shell-by-Shell Tactical Reload + Final Pump Rack!
                float env = rel < 0.14F ? ease(rel / 0.14F) : (rel > 0.88F ? ease((1F - rel) / 0.12F) : 1F);
                rZ = -48F * env * side; rX = 18F * env; rY = 14F * env * side;
                oY = -0.06F * env;
                if (rel >= 0.14F && rel < 0.72F) {
                    float cyc = ((rel - 0.14F) / 0.58F) * 3.0F;
                    float f = cyc - (float)Math.floor(cyc);
                    shellFeed = Mth.sin(f * (float)Math.PI);
                    lhX = 2.0F; lhY = -7.0F + shellFeed * 7.2F; lhZ = 9.0F;
                    oY += shellFeed * 0.02F;
                } else if (rel >= 0.72F && rel < 0.88F) {
                    float f = Mth.sin(((rel - 0.72F) / 0.16F) * (float)Math.PI);
                    relBolt = f;
                    lhZ = f * 5.0F;
                }
            } else {
                // Rifles, Pistol, Sniper, Minigun Magazine Reload Choreography
                float env = rel < 0.14F ? ease(rel / 0.14F) : (rel > 0.88F ? ease((1F - rel) / 0.12F) : 1F);
                rZ = 28F * env * side; rX = 14F * env; rY = 16F * env * side;
                oY = -0.04F * env;
                if (rel >= 0.14F && rel < 0.38F) {
                    float f = ease((rel - 0.14F) / 0.24F);
                    magY = -f * 13F; magRot = f * 20F;
                    lhX = 1.6F * f; lhY = magY; lhZ = 5.5F * f;
                } else if (rel >= 0.38F && rel < 0.48F) {
                    magVisible = false; magY = -14F; lhY = -13F; lhZ = 5.5F;
                } else if (rel >= 0.48F && rel < 0.70F) {
                    float f = ease((rel - 0.48F) / 0.22F);
                    magY = -(1F - f) * 13F; magRot = (1F - f) * 14F;
                    lhX = 1.6F * (1F - f); lhY = magY; lhZ = 5.5F * (1F - f);
                } else if (rel >= 0.70F && rel < 0.86F) {
                    float f = Mth.sin(((rel - 0.70F) / 0.16F) * (float)Math.PI);
                    oY += f * 0.025F;
                    relBolt = f;
                    lhX = 1.2F * f; lhY = 2.6F * f; lhZ = 7.5F * f;
                }
            }
        } else { lastStage = 0; }

        float sp = ease(sprint);
        float pump = getPump();

        ps.translate(x + oX - 0.08F * side * sp, y + oY - 0.06F * sp, z + oZ);
        ps.mulPose(Axis.YP.rotationDegrees(32F * side * sp + rY - swayX * 120F * sw));
        ps.mulPose(Axis.XP.rotationDegrees(recPitch - 14F * sp + rX - ease(equip) * 32F + pump * 6F + swayY * 105F * sw));
        ps.mulPose(Axis.ZP.rotationDegrees(recRoll + rZ + rhBolt * 16F * side - swayX * 95F * sw));
        return true;
    }
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/client/GunClientEvents.java"
package com.arsenalmod.client;

import com.arsenalmod.ArsenalMod;
import com.arsenalmod.item.*;
import com.arsenalmod.network.*;
import com.arsenalmod.registry.ModEntities;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.Minecraft;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.*;
import net.minecraftforge.client.gui.overlay.VanillaGuiOverlay;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import org.lwjgl.glfw.GLFW;

public class GunClientEvents {
    public static final KeyMapping RELOAD_KEY = new KeyMapping("key.arsenalmod.reload", GLFW.GLFW_KEY_R, "key.categories.arsenalmod");

    @Mod.EventBusSubscriber(modid = ArsenalMod.MODID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
    public static class ModBus {
        @SubscribeEvent public static void onRenderers(EntityRenderersEvent.RegisterRenderers e) {
            e.registerEntityRenderer(ModEntities.BULLET.get(), BulletRenderer::new);
            e.registerEntityRenderer(ModEntities.ROCKET.get(), RocketRenderer::new);
        }
        @SubscribeEvent public static void onKeys(RegisterKeyMappingsEvent e) { e.register(RELOAD_KEY); }
        @SubscribeEvent public static void onGui(RegisterGuiOverlaysEvent e) { e.registerAboveAll("gun_hud", GunHudOverlay.HUD_GUN); }
    }

    @Mod.EventBusSubscriber(modid = ArsenalMod.MODID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
    public static class ForgeBus {
        private static boolean wasDown = false;
        private static long localLastShot = -100L;

        @SubscribeEvent public static void onRenderTick(TickEvent.RenderTickEvent e) {
            if (e.phase == TickEvent.Phase.START) GunAnimationEngine.updateFrame();
        }
        @SubscribeEvent public static void onRenderLevel(RenderLevelStageEvent e) {
            if (e.getStage() == RenderLevelStageEvent.Stage.AFTER_ENTITIES)
                WorldEffectsRenderer.render(e.getPoseStack(), e.getCamera(), e.getPartialTick());
        }
        @SubscribeEvent public static void onClick(InputEvent.InteractionKeyMappingTriggered e) {
            Minecraft mc = Minecraft.getInstance();
            if (mc.player != null && mc.player.getMainHandItem().getItem() instanceof GunItem) {
                if (e.isAttack() || e.isUseItem()) { e.setCanceled(true); e.setSwingHand(false); }
            }
        }
        @SubscribeEvent public static void onClientTick(TickEvent.ClientTickEvent e) {
            if (e.phase != TickEvent.Phase.END) return;
            Minecraft mc = Minecraft.getInstance();
            if (mc.player == null || mc.level == null || mc.screen != null) {
                GunAnimationEngine.isAiming = false; wasDown = false; return;
            }
            ItemStack st = mc.player.getMainHandItem();
            if (!(st.getItem() instanceof GunItem gun)) {
                GunAnimationEngine.isAiming = false; wasDown = false; return;
            }
            GunAnimationEngine.isAiming = mc.options.keyUse.isDown();
            while (RELOAD_KEY.consumeClick()) ModNetwork.INSTANCE.sendToServer(new C2SReloadPacket());
            boolean atk = mc.options.keyAttack.isDown();
            GunType t = gun.getType();
            long now = mc.level.getGameTime();
            boolean want = t.fullAuto ? atk : (atk && !wasDown);
            wasDown = atk;

            if (want && !gun.isReloading(st, now) && now - localLastShot >= t.fireCooldown) {
                if (gun.getAmmo(st) > 0) {
                    localLastShot = now;
                    ModNetwork.INSTANCE.sendToServer(new C2SShootPacket(GunAnimationEngine.isAiming));
                    GunAnimationEngine.onLocalShot(t, mc.player);
                } else {
                    ModNetwork.INSTANCE.sendToServer(new C2SReloadPacket());
                }
            }
        }
        @SubscribeEvent public static void onFov(ComputeFovModifierEvent e) {
            if (e.getPlayer().getMainHandItem().getItem() instanceof GunItem gun && GunAnimationEngine.ads > 0.01F) {
                float base = e.getNewFovModifier();
                e.setNewFovModifier(base + (gun.getType().adsFov - base) * GunAnimationEngine.ads);
            }
        }
        @SubscribeEvent public static void onCrosshair(RenderGuiOverlayEvent.Pre e) {
            Minecraft mc = Minecraft.getInstance();
            if (e.getOverlay() == VanillaGuiOverlay.CROSSHAIR.type() && mc.player != null
                    && mc.player.getMainHandItem().getItem() instanceof GunItem) e.setCanceled(true);
        }
    }
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/client/GunHudOverlay.java"
package com.arsenalmod.client;

import com.arsenalmod.item.*;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.client.gui.overlay.IGuiOverlay;

public class GunHudOverlay {
    public static final IGuiOverlay HUD_GUN = (gui, g, pt, w, h) -> {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null || mc.options.hideGui) return;
        ItemStack st = mc.player.getMainHandItem();
        if (!(st.getItem() instanceof GunItem gun)) return;

        GunType t = gun.getType();
        Font font = mc.font;
        int cx = w / 2, cy = h / 2;

        if (t.isSniper && GunAnimationEngine.ads > 0.70F) {
            int r = Math.min(w, h) * 42 / 100;
            g.fill(0, 0, w, cy - r, 0xFF000000);
            g.fill(0, cy + r, w, h, 0xFF000000);
            g.fill(0, cy - r, cx - r, cy + r, 0xFF000000);
            g.fill(cx + r, cy - r, w, cy + r, 0xFF000000);
            g.fill(cx - r, cy, cx + r, cy + 1, 0xCC000000);
            g.fill(cx, cy - r, cx + 1, cy + r, 0xCC000000);
            for (int i = -4; i <= 4; i++) {
                if (i == 0) continue;
                g.fill(cx + i * 16, cy - 3, cx + i * 16 + 1, cy + 4, 0xCC000000);
                g.fill(cx - 3, cy + i * 16, cx + 4, cy + i * 16 + 1, 0xCC000000);
            }
            g.fill(cx - 1, cy - 1, cx + 2, cy + 2, 0xFFFF2222);
            g.drawString(font, "ZOOM 5x | .338 LAPUA", cx - r + 8, cy + r - 14, 0xFF55FF55);
        } else if (GunAnimationEngine.ads < 0.65F) {
            int gap = (int)(5 + GunAnimationEngine.recZ * 85 + t.spread * 1.4F);
            int len = 7, col = 0xE8FFFFFF;
            g.fill(cx - gap - len, cy, cx - gap, cy + 1, col);
            g.fill(cx + gap + 1, cy, cx + gap + 1 + len, cy + 1, col);
            g.fill(cx, cy - gap - len, cx + 1, cy - gap, col);
            g.fill(cx, cy + gap + 1, cx + 1, cy + gap + 1 + len, col);
            g.fill(cx, cy, cx + 1, cy + 1, 0xFFFF3333);
        }

        if (GunAnimationEngine.hitTimer > 0F) {
            int hc = (GunAnimationEngine.hitHead || GunAnimationEngine.hitKill) ? 0xFFFF2222 : 0xFFFFFFFF;
            int d = 4, l = 6;
            for (int i = 0; i < l; i++) {
                g.fill(cx - d - i, cy - d - i, cx - d - i + 2, cy - d - i + 2, hc);
                g.fill(cx + d + i - 1, cy - d - i, cx + d + i + 1, cy - d - i + 2, hc);
                g.fill(cx - d - i, cy + d + i - 1, cx - d - i + 2, cy + d + i + 1, hc);
                g.fill(cx + d + i - 1, cy + d + i - 1, cx + d + i + 1, cy + d + i + 1, hc);
            }
        }

        int ammo = gun.getAmmo(st);
        long now = mc.level.getGameTime();
        boolean rel = gun.isReloading(st, now);
        int bx = w - 152, by = h - 54;
        g.fill(bx, by, w - 8, h - 8, 0xAA0C1016);
        g.fill(bx, by, bx + 3, h - 8, rel ? 0xFFFFAA00 : (ammo == 0 ? 0xFFFF3333 : 0xFF00E5FF));
        g.drawString(font, t.displayName, bx + 8, by + 6, 0xFFFFFFFF);
        int ac = ammo == 0 ? 0xFFFF4444 : (ammo <= t.maxAmmo / 4 ? 0xFFFFBB33 : 0xFF55FF88);
        g.drawString(font, ammo + " / " + t.maxAmmo, bx + 8, by + 19, ac);
        if (rel) {
            float rp = gun.getReloadProgress(st, now, pt);
            g.fill(bx + 8, by + 33, w - 16, by + 39, 0xFF222222);
            g.fill(bx + 8, by + 33, bx + 8 + (int)((w - 24 - bx) * rp), by + 39, 0xFFFFAA00);
        } else {
            g.drawString(font, "[Esq] Atirar [Dir] Mira [R] Rec.", bx + 8, by + 34, 0xFF99AABB);
        }
    };
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/client/GunItemRenderer.java"
package com.arsenalmod.client;

import com.arsenalmod.item.*;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.*;
import net.minecraft.world.item.*;

public class GunItemRenderer extends BlockEntityWithoutLevelRenderer {
    public GunItemRenderer() { super(Minecraft.getInstance().getBlockEntityRenderDispatcher(), Minecraft.getInstance().getEntityModels()); }

    @Override
    public void renderByItem(ItemStack stack, ItemDisplayContext ctx, PoseStack ps, MultiBufferSource buf, int light, int ov) {
        if (!(stack.getItem() instanceof GunItem gun)) return;
        GunType t = gun.getType();
        boolean fp = ctx == ItemDisplayContext.FIRST_PERSON_RIGHT_HAND || ctx == ItemDisplayContext.FIRST_PERSON_LEFT_HAND;
        if (fp && t.isSniper && GunAnimationEngine.ads > 0.70F) return;

        ps.pushPose();
        ps.translate(0.5F, 0.5F, 0.5F);
        switch (ctx) {
            case GUI -> {
                // Studio 3D isometric side-profile framing filling the inventory slot cleanly!
                float sc = switch (t) {
                    case GLOCK19 -> 2.15F;
                    case AWP_SNIPER -> 0.80F;
                    case RPG7 -> 0.84F;
                    case MINIGUN -> 0.92F;
                    default -> 1.02F;
                };
                ps.scale(sc, sc, sc);
                ps.mulPose(Axis.YP.rotationDegrees(72));
                ps.mulPose(Axis.XP.rotationDegrees(16));
                ps.mulPose(Axis.ZP.rotationDegrees(-28));
                float zOff = (t == GunType.GLOCK19) ? 0.04F : (t == GunType.AWP_SNIPER ? 0.28F : 0.18F);
                ps.translate(0, -0.04F, zOff);
            }
            case THIRD_PERSON_RIGHT_HAND, THIRD_PERSON_LEFT_HAND -> {
                ps.scale(1.05F, 1.05F, 1.05F);
                ps.translate(0, 0.12F, -0.02F);
            }
            case GROUND -> { ps.scale(0.85F, 0.85F, 0.85F); ps.translate(0, 0.15F, 0); }
            case FIXED -> { ps.scale(1.0F, 1.0F, 1.0F); ps.mulPose(Axis.YP.rotationDegrees(90)); }
            default -> {}
        }
        long now = Minecraft.getInstance().level != null ? Minecraft.getInstance().level.getGameTime() : 0L;
        GunModelGeometry.renderGun(t, ps, buf, light, ov, fp, gun.getAmmo(stack), gun.isReloading(stack, now));
        ps.popPose();
    }
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/client/GunModelGeometry.java"
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
            T_RED = 12, T_GREEN = 13, T_FLASH = 14, T_RED_HULL = 15,
            T_GLOVE = 16, T_SLEEVE = 17, T_CARBON = 18, T_BORE = 19;

    // Fine 1/32 block scale -> crisp, slim, true-to-life military proportions!
    private static final float S = 1.0F / 32.0F;

    public static void renderGun(GunType type, PoseStack ps, MultiBufferSource buf, int l, int ov,
                                 boolean fp, int ammo, boolean rel) {
        VertexConsumer vc = buf.getBuffer(RenderType.entityCutoutNoCull(ATLAS));
        float sl = fp ? Math.max(GunAnimationEngine.slide, GunAnimationEngine.relBolt) : 0F;
        float mY = fp ? GunAnimationEngine.magY : 0F, mR = fp ? GunAnimationEngine.magRot : 0F;
        boolean mV = !fp || GunAnimationEngine.magVisible;
        float pm = fp ? Math.max(GunAnimationEngine.getPump(), GunAnimationEngine.relBolt) : 0F;
        float bt = fp ? Math.max(GunAnimationEngine.getBolt(), GunAnimationEngine.relBolt) : 0F;
        float sp = fp ? GunAnimationEngine.spinAngle : 0F;

        switch (type) {
            case GLOCK19 -> glock(ps, vc, l, ov, sl, mY, mV, ammo == 0 && !rel, fp);
            case AK47 -> ak47(ps, vc, l, ov, sl, mY, mR, mV, fp);
            case M4A1 -> m4a1(ps, vc, l, ov, sl, mY, mV, fp);
            case SPAS12 -> spas12(ps, vc, l, ov, pm, sl, fp);
            case AWP_SNIPER -> awp(ps, vc, l, ov, bt, mY, mV, fp);
            case MINIGUN -> minigun(ps, vc, l, ov, sp, fp);
            case RPG7 -> rpg7(ps, vc, l, ov, ammo > 0 || (fp && rel && GunAnimationEngine.whSlide < 0.99F),
                    fp && rel ? GunAnimationEngine.whSlide : 0F, fp && rel ? GunAnimationEngine.whRot : 0F, fp);
        }

        if (fp && GunAnimationEngine.flash > 0.05F) {
            muzzleFlash(ps, vc, type.muzzleY, type.muzzleZ, type.isShotgun || type.isRocket ? 4.8F : 3.2F,
                    GunAnimationEngine.flash, GunAnimationEngine.flashAngle);
        }
    }

    // Properly angled tactical gloved hand + slim forearm angled downward (never clips camera!)
    private static void hand(PoseStack ps, VertexConsumer vc, int l, int ov, float x, float y, float z,
                             float rx, float ry, float rz, boolean right) {
        ps.pushPose();
        ps.translate(x * S, y * S, z * S);
        ps.mulPose(Axis.YP.rotationDegrees(ry));
        ps.mulPose(Axis.XP.rotationDegrees(rx));
        ps.mulPose(Axis.ZP.rotationDegrees(rz));
        // Compact contoured tactical glove wrapping grip
        box(ps, vc, l, ov, T_GLOVE, 0, 0, 0, 2.3F, 2.1F, 2.8F);
        box(ps, vc, l, ov, T_CARBON, 0, 1.0F, -0.4F, 2.15F, 0.35F, 1.25F);
        // Wrapped thumb & curled fingers
        box(ps, vc, l, ov, T_GLOVE, right ? -1.1F : 1.1F, 0.55F, -0.6F, 0.7F, 0.75F, 1.8F);
        box(ps, vc, l, ov, T_GLOVE, right ? -0.95F : 0.95F, -0.4F, -1.2F, 1.5F, 1.3F, 0.8F);
        // Slim forearm angled DOWN-OUTWARD toward player shoulder (zero camera clipping!)
        ps.pushPose();
        ps.translate((right ? 0.55F : -0.55F) * S, -0.7F * S, 1.4F * S);
        ps.mulPose(Axis.XP.rotationDegrees(-24F));
        ps.mulPose(Axis.YP.rotationDegrees(right ? 14F : -14F));
        box(ps, vc, l, ov, T_CARBON, 0, 0, 0.4F, 2.35F, 2.2F, 0.85F); // Cuff
        cyl(ps, vc, l, ov, T_SLEEVE, 0, -0.15F, 5.2F, 1.25F, 1.45F, 9.2F, 2);
        ps.popPose();
        ps.popPose();
    }

    private static void glock(PoseStack ps, VertexConsumer vc, int l, int ov, float sl, float mY, boolean mV, boolean empty, boolean fp) {
        // Slim tactical lower polymer frame
        box(ps, vc, l, ov, T_POLYMER, 0, 0.9F, -1.0F, 1.95F, 1.25F, 10.6F);
        box(ps, vc, l, ov, T_RAIL, 0, 0.1F, -4.4F, 1.45F, 0.42F, 3.6F);
        box(ps, vc, l, ov, T_POLYMER, 0, -1.05F, -0.9F, 0.75F, 0.32F, 3.4F);
        box(ps, vc, l, ov, T_POLYMER, 0, -0.35F, -2.5F, 0.75F, 1.5F, 0.36F);
        rotBox(ps, vc, l, ov, T_CHROME, 0, -0.15F, -0.25F, 0.32F, 1.2F, 0.3F, -22 - sl * 20, 0, 0);
        rotBox(ps, vc, l, ov, T_GRIP, 0, -2.6F, 2.9F, 1.85F, 6.2F, 2.9F, 17, 0, 0);
        // Cylindrical stainless barrel + recessed dark hollow bore!
        cyl(ps, vc, l, ov, T_CHROME, 0, 2.3F, -2.6F, 0.62F, 0.62F, 11.2F, 2);
        cyl(ps, vc, l, ov, T_BORE, 0, 2.3F, -8.25F, 0.44F, 0.44F, 0.3F, 2);

        if (mV) {
            ps.pushPose(); ps.translate(0, mY * S, -mY * 0.28F * S);
            rotBox(ps, vc, l, ov, T_STEEL, 0, -3.0F, 3.0F, 1.38F, 5.8F, 2.1F, 17, 0, 0);
            rotBox(ps, vc, l, ov, T_POLYMER, 0, -5.9F, 3.85F, 1.98F, 0.68F, 2.95F, 17, 0, 0);
            rotBox(ps, vc, l, ov, T_BRASS, 0, -0.1F, 2.1F, 0.75F, 0.6F, 1.4F, 17, 0, 0);
            ps.popPose();
        }
        // Machined chamfered slide + ejection port + tritium sights
        ps.pushPose(); ps.translate(0, 0, (empty ? 2.6F : sl * 3.6F) * S);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 2.35F, -1.2F, 2.12F, 1.65F, 11.4F);
        box(ps, vc, l, ov, T_STEEL, 0, 3.3F, -1.2F, 1.65F, 0.32F, 11.2F);
        box(ps, vc, l, ov, T_BORE, 0.98F, 2.65F, -0.5F, 0.25F, 0.85F, 2.4F); // Ejection port recess
        for (int i = 0; i < 6; i++) box(ps, vc, l, ov, T_BORE, 0, 2.35F, 1.6F + i * 0.45F, 2.18F, 1.2F, 0.16F);
        box(ps, vc, l, ov, T_GUNMETAL, -0.52F, 3.68F, 3.9F, 0.42F, 0.45F, 0.55F);
        box(ps, vc, l, ov, T_GUNMETAL,  0.52F, 3.68F, 3.9F, 0.42F, 0.45F, 0.55F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN, -0.52F, 3.74F, 4.2F, 0.2F, 0.2F, 0.08F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN,  0.52F, 3.74F, 4.2F, 0.2F, 0.2F, 0.08F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_RED, 0, 3.76F, -6.5F, 0.22F, 0.26F, 0.26F);
        ps.popPose();

        if (fp) {
            hand(ps, vc, l, ov, 0.65F, -2.9F, 3.2F, 15, -6, 0, true);
            hand(ps, vc, l, ov, -0.85F + GunAnimationEngine.lhX, -3.2F + GunAnimationEngine.lhY,
                    2.6F + GunAnimationEngine.lhZ, 12, 12, 0, false);
        }
    }

    private static void ak47(PoseStack ps, VertexConsumer vc, int l, int ov, float sl, float mY, float mR, boolean mV, boolean fp) {
        // Slim authentic stamped steel AKM receiver + curved dust cover + selector lever
        box(ps, vc, l, ov, T_GUNMETAL, 0, 1.25F, -0.6F, 2.15F, 2.35F, 11.4F);
        cyl(ps, vc, l, ov, T_STEEL, 0, 2.55F, 0.2F, 1.0F, 1.0F, 9.6F, 2);
        box(ps, vc, l, ov, T_STEEL, 1.12F, 1.0F, 1.2F, 0.18F, 0.35F, 4.2F); // Fire selector
        // Sleek varnished AK wood stock (compact so it never clips camera!)
        rotBox(ps, vc, l, ov, T_WOOD_AK, 0, 0.3F, 9.2F, 1.75F, 2.6F, 8.8F, -8, 0, 0);
        rotBox(ps, vc, l, ov, T_WOOD_AK, 0, -0.75F, 11.4F, 1.72F, 2.1F, 4.4F, -11, 0, 0);
        rotBox(ps, vc, l, ov, T_GUNMETAL, 0, -0.35F, 13.6F, 1.82F, 3.55F, 0.42F, -8, 0, 0);
        rotBox(ps, vc, l, ov, T_WOOD_DARK, 0, -2.45F, 3.5F, 1.52F, 5.2F, 2.1F, 19, 0, 0);
        box(ps, vc, l, ov, T_GUNMETAL, 0, -1.0F, 0.6F, 0.65F, 0.28F, 3.3F);
        // Contoured AK Lower & Upper Wood Handguard
        box(ps, vc, l, ov, T_WOOD_AK, 0, 1.0F, -10.2F, 2.2F, 1.75F, 7.6F);
        cyl(ps, vc, l, ov, T_WOOD_AK, 0, 2.4F, -9.9F, 0.88F, 0.88F, 6.8F, 2);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 1.55F, -14.1F, 2.25F, 2.0F, 0.6F); // Handguard retainer
        // Slender cylindrical gas tube, gas block, cold-hammer barrel + slant brake + hollow bore
        cyl(ps, vc, l, ov, T_STEEL, 0, 2.55F, -15.6F, 0.50F, 0.50F, 3.8F, 2);
        rotBox(ps, vc, l, ov, T_GUNMETAL, 0, 2.05F, -17.5F, 1.08F, 1.9F, 1.15F, 28, 0, 0);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 1.6F, -19.5F, 0.48F, 0.54F, 11.4F, 2);
        cyl(ps, vc, l, ov, T_CHROME, 0, 1.6F, -25.4F, 0.62F, 0.56F, 1.6F, 2);
        cyl(ps, vc, l, ov, T_BORE, 0, 1.6F, -26.25F, 0.42F, 0.42F, 0.25F, 2);
        // Rear tangent leaf sight + iconic hooded front sight post
        box(ps, vc, l, ov, T_GUNMETAL, 0, 3.8F, -5.2F, 1.35F, 0.68F, 2.4F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN, -0.34F, 4.45F, -4.1F, 0.18F, 0.18F, 0.12F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN,  0.34F, 4.45F, -4.1F, 0.18F, 0.18F, 0.12F);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 3.15F, -23.4F, 0.52F, 2.55F, 0.95F);
        box(ps, vc, l, ov, T_GUNMETAL, -0.58F, 4.1F, -23.4F, 0.22F, 1.15F, 0.72F);
        box(ps, vc, l, ov, T_GUNMETAL,  0.58F, 4.1F, -23.4F, 0.22F, 1.15F, 0.72F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_RED, 0, 4.45F, -23.4F, 0.18F, 0.32F, 0.18F);

        // Recessed dark chamber + sliding chrome bolt carrier
        box(ps, vc, l, ov, T_BORE, 1.04F, 2.15F, -1.8F, 0.22F, 0.85F, 4.8F);
        ps.pushPose(); ps.translate(0, 0, sl * 4.2F * S);
        box(ps, vc, l, ov, T_CHROME, 1.08F, 2.15F, -2.6F, 0.26F, 0.75F, 3.8F);
        cyl(ps, vc, l, ov, T_CHROME, 1.72F, 2.15F, -3.7F, 0.28F, 0.28F, 1.35F, 0);
        ps.popPose();

        // Sculpted 3-Segment Curved Banana Magazine
        if (mV) {
            ps.pushPose(); ps.translate(0, mY * S, -mY * 0.16F * S);
            ps.mulPose(Axis.XP.rotationDegrees(-mR));
            rotBox(ps, vc, l, ov, T_GUNMETAL, 0, -2.0F, -4.4F, 1.55F, 3.9F, 2.9F, -12, 0, 0);
            rotBox(ps, vc, l, ov, T_GUNMETAL, 0, -5.3F, -5.35F, 1.52F, 3.7F, 2.85F, -24, 0, 0);
            rotBox(ps, vc, l, ov, T_STEEL,    0, -8.25F, -6.85F, 1.48F, 3.2F, 2.8F, -36, 0, 0);
            rotBox(ps, vc, l, ov, T_BRASS, 0, -0.15F, -4.0F, 0.85F, 0.65F, 1.85F, -12, 0, 0);
            ps.popPose();
        }
        if (fp) {
            hand(ps, vc, l, ov, 0.6F, -2.6F, 3.8F, 16, -6, 0, true);
            hand(ps, vc, l, ov, -1.35F + GunAnimationEngine.lhX, -0.35F + GunAnimationEngine.lhY,
                    -9.4F + GunAnimationEngine.lhZ, -8, 22, -10, false);
        }
    }

    private static void m4a1(PoseStack ps, VertexConsumer vc, int l, int ov, float sl, float mY, boolean mV, boolean fp) {
        // Sleek Forged AR-15 Upper & Lower Receiver + Full-Length Picatinny Rail
        box(ps, vc, l, ov, T_GUNMETAL, 0, 1.45F, -0.6F, 2.15F, 2.75F, 10.6F);
        box(ps, vc, l, ov, T_RAIL, 0, 3.02F, -6.2F, 1.38F, 0.42F, 21.8F);
        // Cylindrical Buffer Tube + Sleek Magpul CTR Tactical Stock
        cyl(ps, vc, l, ov, T_STEEL, 0, 2.25F, 8.6F, 0.78F, 0.78F, 8.4F, 2);
        box(ps, vc, l, ov, T_TAN, 0, 1.15F, 11.4F, 1.95F, 3.7F, 4.8F);
        box(ps, vc, l, ov, T_POLYMER, 0, 0.9F, 14.0F, 2.05F, 4.1F, 0.68F);
        // Slim Quad-Rail Handguard + FDE Rail Covers + Angled Tactical Foregrip + Side PEQ Laser
        box(ps, vc, l, ov, T_GUNMETAL, 0, 1.75F, -11.4F, 2.25F, 2.35F, 10.8F);
        box(ps, vc, l, ov, T_TAN, -1.22F, 1.75F, -11.4F, 0.28F, 1.05F, 8.4F);
        box(ps, vc, l, ov, T_TAN,  1.22F, 1.75F, -11.4F, 0.28F, 1.05F, 8.4F);
        box(ps, vc, l, ov, T_TAN, 1.35F, 2.55F, -14.2F, 0.95F, 0.85F, 3.2F); // Side laser box
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN, 1.45F, 2.55F, -15.85F, 0.22F, 0.22F, 0.12F);
        rotBox(ps, vc, l, ov, T_GRIP, 0, -0.8F, -12.0F, 1.35F, 3.1F, 1.65F, -24, 0, 0);
        rotBox(ps, vc, l, ov, T_GRIP, 0, -2.35F, 3.1F, 1.55F, 5.2F, 2.15F, 18, 0, 0);
        // Slender Barrel + Matte Carbon Cylindrical Suppressor + Hollow Bore
        cyl(ps, vc, l, ov, T_STEEL, 0, 1.75F, -18.6F, 0.52F, 0.52F, 3.8F, 2);
        cyl(ps, vc, l, ov, T_CARBON, 0, 1.75F, -23.8F, 0.92F, 0.92F, 6.8F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 1.75F, -20.8F, 0.98F, 0.98F, 0.55F, 2);
        cyl(ps, vc, l, ov, T_BORE, 0, 1.75F, -27.25F, 0.52F, 0.52F, 0.25F, 2);
        // Open-Frame EOTech Holographic Red-Dot Sight (Centered at Y = +5.45!)
        box(ps, vc, l, ov, T_POLYMER, 0, 3.65F, -1.2F, 2.1F, 0.78F, 4.4F);
        box(ps, vc, l, ov, T_GUNMETAL, -1.08F, 5.45F, -1.2F, 0.26F, 2.85F, 3.0F);
        box(ps, vc, l, ov, T_GUNMETAL,  1.08F, 5.45F, -1.2F, 0.26F, 2.85F, 3.0F);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 6.82F, -1.2F, 2.42F, 0.28F, 3.0F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_RED, 0, 5.45F, -1.2F, 0.16F, 0.16F, 0.16F);

        box(ps, vc, l, ov, T_BORE, 1.05F, 2.15F, -1.2F, 0.2F, 0.85F, 3.2F);
        ps.pushPose(); ps.translate(0, 0, sl * 3.4F * S);
        box(ps, vc, l, ov, T_CHROME, 1.08F, 2.15F, -1.2F, 0.18F, 0.78F, 3.0F);
        box(ps, vc, l, ov, T_STEEL, 0, 2.95F, 4.95F, 1.75F, 0.45F, 0.75F);
        ps.popPose();

        if (mV) {
            ps.pushPose(); ps.translate(0, mY * S, 0);
            rotBox(ps, vc, l, ov, T_STEEL, 0, -3.2F, -3.8F, 1.48F, 6.6F, 3.1F, -7, 0, 0);
            rotBox(ps, vc, l, ov, T_TAN, 0, -6.55F, -4.2F, 1.65F, 0.82F, 3.25F, -7, 0, 0);
            box(ps, vc, l, ov, T_BRASS, 0, -0.05F, -3.5F, 0.9F, 0.6F, 1.9F);
            ps.popPose();
        }
        if (fp) {
            hand(ps, vc, l, ov, 0.6F, -2.5F, 3.4F, 16, -6, 0, true);
            hand(ps, vc, l, ov, -1.35F + GunAnimationEngine.lhX, -1.1F + GunAnimationEngine.lhY,
                    -10.8F + GunAnimationEngine.lhZ, -12, 22, -10, false);
        }
    }

    private static void spas12(PoseStack ps, VertexConsumer vc, int l, int ov, float pm, float sl, boolean fp) {
        box(ps, vc, l, ov, T_GUNMETAL, 0, 1.45F, -0.6F, 2.45F, 2.95F, 11.4F);
        rotBox(ps, vc, l, ov, T_STEEL, 0, 0.45F, 8.8F, 1.85F, 1.55F, 8.6F, -8, 0, 0);
        box(ps, vc, l, ov, T_POLYMER, 0, -0.4F, 13.3F, 2.05F, 4.2F, 0.8F);
        box(ps, vc, l, ov, T_STEEL, 0, 3.4F, 2.2F, 2.05F, 0.42F, 9.2F); // Over-top folding stock strut
        rotBox(ps, vc, l, ov, T_GRIP, 0, -2.45F, 3.6F, 1.72F, 5.4F, 2.35F, 18, 0, 0);
        // Ventilated Heatshield + Smooth Round Heavy Barrel + Magazine Tube + Dark Bore
        box(ps, vc, l, ov, T_CARBON, 0, 2.35F, -13.2F, 2.25F, 1.9F, 13.6F);
        for (int i = 0; i < 6; i++) box(ps, vc, l, ov, T_BORE, 0, 3.32F, -8.2F - i * 1.9F, 1.4F, 0.14F, 0.95F);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 2.15F, -21.6F, 0.72F, 0.76F, 4.8F, 2);
        cyl(ps, vc, l, ov, T_BORE, 0, 2.15F, -24.05F, 0.54F, 0.54F, 0.25F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 0.25F, -13.6F, 0.68F, 0.68F, 14.6F, 2);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 1.2F, -20.2F, 1.65F, 2.7F, 0.85F);
        // Ghost Ring Luminous Iron Sights
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN, -0.45F, 4.3F, -2.2F, 0.18F, 0.18F, 0.1F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN,  0.45F, 4.3F, -2.2F, 0.18F, 0.18F, 0.1F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_RED, 0, 4.3F, -22.8F, 0.22F, 0.26F, 0.22F);

        box(ps, vc, l, ov, T_BORE, 1.2F, 2.0F, -2.0F, 0.2F, 1.0F, 3.6F);
        ps.pushPose(); ps.translate(0, 0, Math.max(sl, pm) * 3.8F * S);
        box(ps, vc, l, ov, T_CHROME, 1.22F, 2.0F, -2.0F, 0.2F, 0.92F, 3.4F);
        ps.popPose();

        // Visible Red 12ga Shell Sliding into Receiver during Reload!
        if (fp && GunAnimationEngine.shellFeed > 0.05F) {
            ps.pushPose();
            ps.translate(0, (-4.5F + GunAnimationEngine.shellFeed * 4.5F) * S, -2.0F * S);
            cyl(ps, vc, l, ov, T_RED_HULL, 0, 0, 0, 0.42F, 0.42F, 1.7F, 2);
            cyl(ps, vc, l, ov, T_BRASS, 0, 0, 0.95F, 0.44F, 0.44F, 0.55F, 2);
            ps.popPose();
        }

        // Ribbed Sliding Pump Forend
        ps.pushPose(); ps.translate(0, 0, pm * 5.0F * S);
        cyl(ps, vc, l, ov, T_GRIP, 0, 0.1F, -12.6F, 1.48F, 1.48F, 7.6F, 2);
        for (int i = 0; i < 6; i++) cyl(ps, vc, l, ov, T_POLYMER, 0, 0.1F, -15.6F + i * 1.2F, 1.56F, 1.56F, 0.34F, 2);
        if (fp) hand(ps, vc, l, ov, -1.4F + GunAnimationEngine.lhX, -1.1F + GunAnimationEngine.lhY,
                -11.4F + GunAnimationEngine.lhZ, -10, 22, -10, false);
        ps.popPose();
        if (fp) hand(ps, vc, l, ov, 0.6F, -2.65F, 4.0F, 16, -6, 0, true);
    }

    private static void awp(PoseStack ps, VertexConsumer vc, int l, int ov, float bt, float mY, boolean mV, boolean fp) {
        // Olive Drab Iconic AWP Precision Chassis
        box(ps, vc, l, ov, T_OLIVE, 0, 0.85F, -0.8F, 2.35F, 2.55F, 12.6F);
        box(ps, vc, l, ov, T_OLIVE, 0, 1.0F, -11.4F, 2.15F, 2.15F, 9.2F);
        box(ps, vc, l, ov, T_OLIVE, 0, 1.3F, 9.6F, 2.05F, 1.45F, 9.4F);
        box(ps, vc, l, ov, T_OLIVE, 0, -1.7F, 9.8F, 1.85F, 1.3F, 8.6F);
        box(ps, vc, l, ov, T_OLIVE, 0, -0.25F, 13.4F, 2.15F, 4.2F, 2.4F);
        box(ps, vc, l, ov, T_POLYMER, 0, 2.65F, 9.8F, 2.0F, 1.15F, 4.8F);
        box(ps, vc, l, ov, T_POLYMER, 0, -0.25F, 14.8F, 2.25F, 4.4F, 0.85F);
        rotBox(ps, vc, l, ov, T_GRIP, 0, -1.7F, 4.2F, 1.72F, 4.6F, 2.3F, 15, 0, 0);
        // Folded Twin Bipod Legs
        cyl(ps, vc, l, ov, T_GUNMETAL, -1.15F, -0.65F, -12.0F, 0.32F, 0.32F, 7.6F, 2);
        cyl(ps, vc, l, ov, T_GUNMETAL,  1.15F, -0.65F, -12.0F, 0.32F, 0.32F, 7.6F, 2);
        // Heavy Fluted Free-Float Barrel + Slotted Tank Muzzle Brake + Hollow Bore
        box(ps, vc, l, ov, T_GUNMETAL, 0, 2.3F, -1.8F, 2.05F, 1.55F, 10.6F);
        cyl(ps, vc, l, ov, T_STEEL, 0, 2.05F, -23.5F, 0.56F, 0.72F, 16.8F, 2);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 2.05F, -32.6F, 2.15F, 1.45F, 2.6F);
        box(ps, vc, l, ov, T_BORE, 0, 2.05F, -32.6F, 2.22F, 0.65F, 0.75F);
        cyl(ps, vc, l, ov, T_BORE, 0, 2.05F, -33.95F, 0.45F, 0.45F, 0.25F, 2);
        // Sculpted High-Power Sniper Scope + Conical Objective Bell + Reflective Lenses
        box(ps, vc, l, ov, T_GUNMETAL, 0, 3.95F, -4.4F, 1.45F, 1.55F, 1.05F);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 3.95F,  1.0F, 1.45F, 1.55F, 1.05F);
        cyl(ps, vc, l, ov, T_CARBON, 0, 5.85F, -1.8F, 0.92F, 0.92F, 12.2F, 2);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 5.85F, -10.2F, 1.48F, 0.96F, 4.8F, 2);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 5.85F,  5.2F, 0.96F, 1.22F, 2.8F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 7.15F, -1.6F, 0.50F, 0.50F, 0.95F, 1);
        cyl(ps, vc, l, ov, T_STEEL, 1.32F, 5.85F, -1.6F, 0.50F, 0.50F, 0.95F, 0);
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_LENS, 0, 5.85F, -12.62F, 1.28F, 1.28F, 0.12F, 2);
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_LENS, 0, 5.85F,  6.62F, 1.02F, 1.02F, 0.12F, 2);

        // Animated Bolt-Action Handle
        ps.pushPose();
        ps.translate(1.12F * S, 2.35F * S, (2.2F + bt * 4.2F) * S);
        ps.mulPose(Axis.ZP.rotationDegrees(bt * 60F));
        cyl(ps, vc, l, ov, T_CHROME, 0.85F, 0, 0, 0.24F, 0.24F, 1.9F, 0);
        cyl(ps, vc, l, ov, T_CARBON, 1.95F, 0, 0, 0.48F, 0.48F, 0.9F, 0);
        ps.popPose();

        if (mV) {
            ps.pushPose(); ps.translate(0, mY * S, 0);
            box(ps, vc, l, ov, T_GUNMETAL, 0, -2.5F, -3.2F, 1.65F, 4.1F, 4.1F);
            box(ps, vc, l, ov, T_BRASS, 0, -0.35F, -3.2F, 0.92F, 0.65F, 2.7F);
            ps.popPose();
        }
        if (fp) {
            hand(ps, vc, l, ov, 0.65F + bt * 1.9F, -2.35F + bt * 3.8F, 4.6F + bt * 1.6F, 14 - bt * 24, -8, 0, true);
            hand(ps, vc, l, ov, -1.4F + GunAnimationEngine.lhX, -0.5F + GunAnimationEngine.lhY,
                    -10.2F + GunAnimationEngine.lhZ, -10, 24, -10, false);
        }
    }

    private static void minigun(PoseStack ps, VertexConsumer vc, int l, int ov, float spin, boolean fp) {
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 0.8F, 2.0F, 2.75F, 2.75F, 10.6F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 0.8F, 7.8F, 2.25F, 1.85F, 2.0F, 2);
        cyl(ps, vc, l, ov, T_CARBON, 0, 0.8F, -5.0F, 2.95F, 2.95F, 3.8F, 2);
        box(ps, vc, l, ov, T_POLYMER, 0, 5.6F, -2.6F, 5.0F, 0.88F, 1.15F);
        box(ps, vc, l, ov, T_STEEL, -2.25F, 3.55F, -2.6F, 0.72F, 4.0F, 1.0F);
        box(ps, vc, l, ov, T_STEEL,  2.25F, 3.55F, -2.6F, 0.72F, 4.0F, 1.0F);
        cyl(ps, vc, l, ov, T_GRIP, 0, 0.8F, 10.0F, 0.52F, 0.52F, 4.6F, 0);
        box(ps, vc, l, ov, T_GUNMETAL, -2.0F, 0.8F, 8.8F, 0.58F, 0.85F, 2.2F);
        box(ps, vc, l, ov, T_GUNMETAL,  2.0F, 0.8F, 8.8F, 0.58F, 0.85F, 2.2F);
        cyl(ps, vc, l, ov, T_OLIVE, -3.9F, -3.5F, 0.8F, 2.75F, 2.75F, 6.8F, 2);
        rotBox(ps, vc, l, ov, T_BRASS, -2.45F, -0.75F, 0.6F, 1.7F, 2.4F, 2.8F, 0, 0, -28);

        ps.pushPose();
        ps.translate(0, 0.8F * S, 0);
        ps.mulPose(Axis.ZP.rotationDegrees(spin));
        for (int i = 0; i < 6; i++) {
            float rad = (float)Math.toRadians(i * 60.0);
            float bx = Mth.cos(rad) * 1.92F, by = Mth.sin(rad) * 1.92F;
            cyl(ps, vc, l, ov, (i % 2 == 0) ? T_CHROME : T_STEEL, bx, by, -15.6F, 0.42F, 0.42F, 20.8F, 2);
            cyl(ps, vc, l, ov, T_BORE, bx, by, -26.05F, 0.28F, 0.28F, 0.25F, 2);
        }
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 0, -12.6F, 2.65F, 2.65F, 1.1F, 2);
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 0, -22.6F, 2.65F, 2.65F, 1.25F, 2);
        ps.popPose();

        if (fp) {
            hand(ps, vc, l, ov, 0.85F, 0.7F, 10.0F, 0, -6, 0, true);
            hand(ps, vc, l, ov, -1.6F, 5.75F, -2.6F, -24, 18, -22, false);
        }
    }

    // COMPLETELY REBUILT SLEEK MILITARY RPG-7 (True Slender Tube + Walnut Heatguard + Hollow Venturi + PGO-7 + Razor-Sharp PG-7V Warhead!)
    private static void rpg7(PoseStack ps, VertexConsumer vc, int l, int ov, boolean hasWh, float whSl, float whRot, boolean fp) {
        // Slender authentic 40mm steel launcher tube (diameter = 2.4 sub-voxels = super sleek!)
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 2.2F, -2.0F, 1.18F, 1.18F, 25.5F, 2);
        // Dark hollow muzzle opening (visible when warhead is fired!)
        cyl(ps, vc, l, ov, T_BORE, 0, 2.2F, -14.8F, 0.92F, 0.92F, 0.4F, 2);
        // Front reinforcement collar & retention ring
        cyl(ps, vc, l, ov, T_STEEL, 0, 2.2F, -14.2F, 1.42F, 1.42F, 1.3F, 2);
        // Contoured Dark Walnut Wood Heatshield + Steel Clamp Bands
        cyl(ps, vc, l, ov, T_WOOD_DARK, 0, 2.2F, 1.8F, 1.52F, 1.52F, 9.6F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 2.2F, -2.4F, 1.60F, 1.60F, 0.52F, 2);
        cyl(ps, vc, l, ov, T_STEEL, 0, 2.2F,  6.0F, 1.60F, 1.60F, 0.52F, 2);
        // Authentic Tapered Venturi Exhaust Cone + Hollow Dark Exhaust Throat!
        cyl(ps, vc, l, ov, T_GUNMETAL, 0, 2.2F, 12.4F, 1.22F, 2.05F, 5.2F, 2);
        cyl(ps, vc, l, ov, T_STEEL,    0, 2.2F, 15.1F, 2.08F, 2.15F, 0.65F, 2);
        cyl(ps, vc, l, ov, T_BORE,     0, 2.2F, 15.45F, 1.75F, 1.75F, 0.35F, 2);
        // Trigger Housing, Hammer, Curved Guard & Dual Walnut Grips
        box(ps, vc, l, ov, T_GUNMETAL, 0, 0.7F, -5.6F, 1.15F, 1.1F, 3.8F);
        rotBox(ps, vc, l, ov, T_WOOD_DARK, 0, -1.65F, -4.6F, 1.32F, 4.6F, 1.75F, 17, 0, 0);
        box(ps, vc, l, ov, T_GUNMETAL, 0, -0.55F, -6.7F, 0.55F, 0.25F, 2.6F);
        rotBox(ps, vc, l, ov, T_WOOD_DARK, 0, -1.55F,  2.2F, 1.32F, 4.2F, 1.68F, -14, 0, 0);
        // Detailed Left-Side PGO-7 Optical Scope (angled dovetail bracket + tapered optic + lens + rubber eyecup)
        rotBox(ps, vc, l, ov, T_GUNMETAL, -1.15F, 3.1F, -4.2F, 1.4F, 0.45F, 1.8F, 0, 0, -35);
        cyl(ps, vc, l, ov, T_GUNMETAL, -2.05F, 3.95F, -4.4F, 0.68F, 0.62F, 4.8F, 2);
        cyl(ps, vc, l, ov, T_CARBON,   -2.05F, 3.95F, -1.6F, 0.58F, 0.78F, 1.6F, 2); // Rubber eyecup
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_LENS, -2.05F, 3.95F, -6.85F, 0.52F, 0.52F, 0.1F, 2);
        // Flip-Up Ladder Iron Sights (aligned at Y = +5.40!)
        box(ps, vc, l, ov, T_GUNMETAL, 0, 4.3F, -13.4F, 0.35F, 2.15F, 0.48F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_RED, 0, 5.40F, -13.4F, 0.22F, 0.26F, 0.22F);
        box(ps, vc, l, ov, T_GUNMETAL, -0.45F, 4.55F, -4.6F, 0.25F, 1.75F, 0.35F);
        box(ps, vc, l, ov, T_GUNMETAL,  0.45F, 4.55F, -4.6F, 0.25F, 1.75F, 0.35F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN, -0.45F, 5.40F, -4.4F, 0.18F, 0.18F, 0.1F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GREEN,  0.45F, 5.40F, -4.4F, 0.18F, 0.18F, 0.1F);

        // Razor-Sharp Authentic PG-7V HEAT Warhead (slides cleanly out/in & twist-locks on reload!)
        if (hasWh) {
            ps.pushPose();
            ps.translate(0, 2.2F * S, (-15.0F - whSl * 14.0F) * S);
            ps.mulPose(Axis.ZP.rotationDegrees(whRot));
            // Booster stem visible while sliding into tube
            if (whSl > 0.02F) cyl(ps, vc, l, ov, T_STEEL, 0, 0, 4.2F, 0.65F, 0.65F, 8.2F, 2);
            // Tapered rear skirt -> olive bulbous warhead -> brass stencil ring -> sleek cone -> standoff nose -> fuse
            cyl(ps, vc, l, ov, T_OLIVE,  0, 0, -2.0F, 2.15F, 1.02F, 3.8F, 2);
            cyl(ps, vc, l, ov, T_OLIVE,  0, 0, -5.0F, 2.22F, 2.22F, 2.4F, 2);
            cyl(ps, vc, l, ov, T_BRASS,  0, 0, -5.0F, 2.28F, 2.28F, 0.48F, 2);
            cyl(ps, vc, l, ov, T_OLIVE,  0, 0, -8.4F, 0.68F, 2.18F, 4.6F, 2);
            cyl(ps, vc, l, ov, T_STEEL,  0, 0, -11.4F, 0.38F, 0.64F, 1.6F, 2);
            cyl(ps, vc, l, ov, T_BRASS,  0, 0, -12.8F, 0.20F, 0.36F, 1.3F, 2);
            ps.popPose();
        }

        if (fp) {
            hand(ps, vc, l, ov, 0.55F, -2.0F, -4.2F, 16, -6, 0, true);
            hand(ps, vc, l, ov, -1.05F + GunAnimationEngine.lhX, -1.75F + GunAnimationEngine.lhY,
                    2.0F + GunAnimationEngine.lhZ, -10, 18, 0, false);
        }
    }

    public static void renderRocket3D(PoseStack ps, MultiBufferSource buf, int l) {
        VertexConsumer vc = buf.getBuffer(RenderType.entityCutoutNoCull(ATLAS));
        int ov = OverlayTexture.NO_OVERLAY;
        cyl(ps, vc, l, ov, T_STEEL, 0, 0, -6.5F, 0.72F, 0.72F, 9.2F, 2);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 0, -10.5F, 5.4F, 0.26F, 2.4F);
        box(ps, vc, l, ov, T_GUNMETAL, 0, 0, -10.5F, 0.26F, 5.4F, 2.4F);
        cyl(ps, vc, l, ov, T_OLIVE, 0, 0, 0.2F, 2.25F, 1.1F, 4.2F, 2);
        cyl(ps, vc, l, ov, T_BRASS, 0, 0, 1.2F, 2.30F, 2.30F, 0.55F, 2);
        cyl(ps, vc, l, ov, T_OLIVE, 0, 0, 4.8F, 0.65F, 2.22F, 4.8F, 2);
        cyl(ps, vc, l, ov, T_BRASS, 0, 0, 8.0F, 0.20F, 0.55F, 2.0F, 2);
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_FLASH, 0, 0, -13.0F, 1.15F, 0.2F, 4.2F, 2);
    }

    public static void renderBullet3D(PoseStack ps, MultiBufferSource buf) {
        VertexConsumer vc = buf.getBuffer(RenderType.entityCutoutNoCull(ATLAS));
        int ov = OverlayTexture.NO_OVERLAY;
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_BRASS, 0, 0, 1.0F, 0.16F, 0.34F, 2.0F, 2);
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_FLASH, 0, 0, -2.2F, 0.28F, 0.08F, 4.8F, 2);
    }

    private static void muzzleFlash(PoseStack ps, VertexConsumer vc, float y, float z, float sz, float a, float ang) {
        int ov = OverlayTexture.NO_OVERLAY;
        float sc = sz * (0.65F + 0.55F * a);
        ps.pushPose();
        ps.translate(0, y * S, (z - 1.0F) * S);
        ps.mulPose(Axis.ZP.rotationDegrees(ang));
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_FLASH, 0, 0, 0, sc * 2.4F, sc * 0.32F, sc * 0.25F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_FLASH, 0, 0, 0, sc * 0.32F, sc * 2.4F, sc * 0.25F);
        rotBox(ps, vc, LightTexture.FULL_BRIGHT, ov, T_FLASH, 0, 0, 0, sc * 1.7F, sc * 0.24F, sc * 0.25F, 0, 0, 45);
        rotBox(ps, vc, LightTexture.FULL_BRIGHT, ov, T_FLASH, 0, 0, 0, sc * 1.7F, sc * 0.24F, sc * 0.25F, 0, 0, -45);
        cyl(ps, vc, LightTexture.FULL_BRIGHT, ov, T_FLASH, 0, 0, -sc * 0.65F, 0.12F, sc * 0.38F, sc * 1.8F, 2);
        ps.popPose();
    }

    // Smooth 10-sided cylinder / tapered frustum (axis: 0=X, 1=Y, 2=Z; rA = -axis end, rB = +axis end)
    public static void cyl(PoseStack ps, VertexConsumer vc, int light, int ov, int tile,
                           float cx, float cy, float cz, float rA, float rB, float len, int axis) {
        ps.pushPose();
        ps.translate(cx * S, cy * S, cz * S);
        if (axis == 0) ps.mulPose(Axis.YP.rotationDegrees(90));
        else if (axis == 1) ps.mulPose(Axis.XP.rotationDegrees(90));

        float z0 = -len * 0.5F * S, z1 = len * 0.5F * S, ra = rA * S, rb = rB * S;
        int col = tile % 8, row = tile / 8;
        float u0 = (col * 32F + 2F) / 256F, u1 = ((col + 1) * 32F - 2F) / 256F;
        float v0 = (row * 32F + 2F) / 256F, v1 = ((row + 1) * 32F - 2F) / 256F;
        PoseStack.Pose pose = ps.last(); Matrix4f m = pose.pose(); Matrix3f n = pose.normal();

        int segs = 10;
        for (int i = 0; i < segs; i++) {
            float a0 = (float)(i * 2.0 * Math.PI / segs), a1 = (float)((i + 1) * 2.0 * Math.PI / segs);
            float c0 = Mth.cos(a0), s0 = Mth.sin(a0), c1 = Mth.cos(a1), s1 = Mth.sin(a1);
            float nx = (c0 + c1) * 0.5F, ny = (s0 + s1) * 0.5F;
            int sh = (int)(168 + 87 * Mth.clamp(ny * 0.55F + 0.5F, 0F, 1F));
            quad(vc, m, n, c0*ra, s0*ra, z0, c1*ra, s1*ra, z0, c1*rb, s1*rb, z1, c0*rb, s0*rb, z1, u0, v0, u1, v1, sh, light, ov, nx, ny, 0);
            quad(vc, m, n, 0, 0, z0, c1*ra, s1*ra, z0, c0*ra, s0*ra, z0, 0, 0, z0, u0, v0, u1, v1, 215, light, ov, 0, 0, -1);
            quad(vc, m, n, 0, 0, z1, c0*rb, s0*rb, z1, c1*rb, s1*rb, z1, 0, 0, z1, u0, v0, u1, v1, 195, light, ov, 0, 0, 1);
        }
        ps.popPose();
    }

    public static void rotBox(PoseStack ps, VertexConsumer vc, int l, int ov, int tile,
                              float cx, float cy, float cz, float w, float h, float d, float rx, float ry, float rz) {
        ps.pushPose();
        ps.translate(cx * S, cy * S, cz * S);
        if (ry != 0) ps.mulPose(Axis.YP.rotationDegrees(ry));
        if (rx != 0) ps.mulPose(Axis.XP.rotationDegrees(rx));
        if (rz != 0) ps.mulPose(Axis.ZP.rotationDegrees(rz));
        box(ps, vc, l, ov, tile, 0, 0, 0, w, h, d);
        ps.popPose();
    }

    public static void box(PoseStack ps, VertexConsumer vc, int light, int ov, int tile,
                           float cx, float cy, float cz, float w, float h, float d) {
        float x0 = (cx - w * 0.5F) * S, x1 = (cx + w * 0.5F) * S;
        float y0 = (cy - h * 0.5F) * S, y1 = (cy + h * 0.5F) * S;
        float z0 = (cz - d * 0.5F) * S, z1 = (cz + d * 0.5F) * S;
        int col = tile % 8, row = tile / 8;
        float u0 = (col * 32F + 2F) / 256F, u1 = ((col + 1) * 32F - 2F) / 256F;
        float v0 = (row * 32F + 2F) / 256F, v1 = ((row + 1) * 32F - 2F) / 256F;
        PoseStack.Pose pose = ps.last(); Matrix4f m = pose.pose(); Matrix3f n = pose.normal();

        quad(vc, m, n, x0, y1, z1, x1, y1, z1, x1, y1, z0, x0, y1, z0, u0, v0, u1, v1, 255, light, ov, 0, 1, 0);
        quad(vc, m, n, x0, y0, z0, x1, y0, z0, x1, y0, z1, x0, y0, z1, u0, v0, u1, v1, 155, light, ov, 0, -1, 0);
        quad(vc, m, n, x1, y0, z0, x0, y0, z0, x0, y1, z0, x1, y1, z0, u0, v0, u1, v1, 225, light, ov, 0, 0, -1);
        quad(vc, m, n, x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1, u0, v0, u1, v1, 215, light, ov, 0, 0, 1);
        quad(vc, m, n, x1, y0, z1, x1, y0, z0, x1, y1, z0, x1, y1, z1, u0, v0, u1, v1, 198, light, ov, 1, 0, 0);
        quad(vc, m, n, x0, y0, z0, x0, y0, z1, x0, y1, z1, x0, y1, z0, u0, v0, u1, v1, 188, light, ov, -1, 0, 0);
    }

    private static void quad(VertexConsumer vc, Matrix4f m, Matrix3f n,
                             float x0, float y0, float z0, float x1, float y1, float z1,
                             float x2, float y2, float z2, float x3, float y3, float z3,
                             float u0, float v0, float u1, float v1, int c, int l, int ov, float nx, float ny, float nz) {
        vc.vertex(m, x0, y0, z0).color(c,c,c,255).uv(u0, v1).overlayCoords(ov).uv2(l).normal(n, nx, ny, nz).endVertex();
        vc.vertex(m, x1, y1, z1).color(c,c,c,255).uv(u1, v1).overlayCoords(ov).uv2(l).normal(n, nx, ny, nz).endVertex();
        vc.vertex(m, x2, y2, z2).color(c,c,c,255).uv(u1, v0).overlayCoords(ov).uv2(l).normal(n, nx, ny, nz).endVertex();
        vc.vertex(m, x3, y3, z3).color(c,c,c,255).uv(u0, v0).overlayCoords(ov).uv2(l).normal(n, nx, ny, nz).endVertex();
    }
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/client/RocketRenderer.java"
package com.arsenalmod.client;

import com.arsenalmod.entity.RocketEntity;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.entity.*;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.phys.Vec3;

public class RocketRenderer extends EntityRenderer<RocketEntity> {
    public RocketRenderer(EntityRendererProvider.Context c) { super(c); }
    @Override public ResourceLocation getTextureLocation(RocketEntity e) { return GunModelGeometry.ATLAS; }
    @Override
    public void render(RocketEntity e, float yaw, float pt, PoseStack ps, MultiBufferSource buf, int light) {
        Vec3 v = e.getDeltaMovement();
        double hz = Math.sqrt(v.x * v.x + v.z * v.z);
        ps.pushPose();
        ps.mulPose(Axis.YP.rotationDegrees((float)(Math.atan2(v.x, v.z) * 180.0 / Math.PI)));
        ps.mulPose(Axis.XP.rotationDegrees(-(float)(Math.atan2(v.y, hz) * 180.0 / Math.PI)));
        GunModelGeometry.renderRocket3D(ps, buf, light);
        ps.popPose();
    }
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/client/WorldEffectsRenderer.java"
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
import org.joml.Quaternionf;
import java.util.*;

public class WorldEffectsRenderer {
    public static final ResourceLocation HOLE_TEX = new ResourceLocation(ArsenalMod.MODID, "textures/entity/bullet_hole.png");
    public static final ResourceLocation PUFF_TEX = new ResourceLocation(ArsenalMod.MODID, "textures/entity/smoke_puff.png");

    static class Hole { double x, y, z; Direction d; float roll, age; Hole(double x,double y,double z,Direction d){this.x=x;this.y=y;this.z=z;this.d=d;roll=(float)(Math.random()*360);} }
    static class Shell { double x,y,z,vx,vy,vz; float rx,ry,vrx,vry,age; boolean sh; Shell(double x,double y,double z,double vx,double vy,double vz,boolean sh){this.x=x;this.y=y;this.z=z;this.vx=vx;this.vy=vy;this.vz=vz;this.sh=sh;vrx=(float)(460+Math.random()*460);vry=(float)(300+Math.random()*400);} }
    static class Spark { double x,y,z,vx,vy,vz; float age,max; int r,g,b; Spark(double x,double y,double z,double vx,double vy,double vz,float max,int r,int g,int b){this.x=x;this.y=y;this.z=z;this.vx=vx;this.vy=vy;this.vz=vz;this.max=max;this.r=r;this.g=g;this.b=b;} }
    static class Puff { double x,y,z,vx,vy,vz; float sz,grow,age,max; int r,g,b,a0; boolean bright; Puff(double x,double y,double z,double vx,double vy,double vz,float sz,float grow,float max,int r,int g,int b,int a0,boolean br){this.x=x;this.y=y;this.z=z;this.vx=vx;this.vy=vy;this.vz=vz;this.sz=sz;this.grow=grow;this.max=max;this.r=r;this.g=g;this.b=b;this.a0=a0;this.bright=br;} }
    static class Tracer { Vec3 a, b; float age; Tracer(Vec3 a, Vec3 b){this.a=a;this.b=b;} }

    private static final List<Hole> HOLES = new ArrayList<>();
    private static final List<Shell> SHELLS = new ArrayList<>();
    private static final List<Spark> SPARKS = new ArrayList<>();
    private static final List<Puff> PUFFS = new ArrayList<>();
    private static final List<Tracer> TRACERS = new ArrayList<>();
    private static long lastNano = System.nanoTime();

    private static double rnd(double s) { return (Math.random() - 0.5) * 2.0 * s; }

    public static void handleFx(double x, double y, double z, int kind, Direction dir) {
        if (kind == 0) { // Block impact: 64x64 hole + hot metal streak sparks + soft dust cloud
            if (HOLES.size() >= 180) HOLES.remove(0);
            HOLES.add(new Hole(x, y, z, dir));
            double nx = dir.getStepX(), ny = dir.getStepY(), nz = dir.getStepZ();
            for (int i = 0; i < 10; i++) addSpark(x+nx*0.02, y+ny*0.02, z+nz*0.02, nx*2.8+rnd(2.4), ny*2.8+rnd(2.2)+0.8, nz*2.8+rnd(2.4), 0.16F+(float)Math.random()*0.18F, 255, 220, 120);
            for (int i = 0; i < 4; i++) addPuff(x+nx*0.05, y+ny*0.05, z+nz*0.05, nx*0.5+rnd(0.45), ny*0.5+0.3+rnd(0.3), nz*0.5+rnd(0.45), 0.14F, 0.7F, 0.55F, 185, 180, 172, 145, false);
        } else if (kind == 1 || kind == 2) { // Entity hit: smooth crimson mist (no minecraft hearts/stars!)
            int n = kind == 2 ? 12 : 6;
            for (int i = 0; i < n; i++) addPuff(x, y, z, rnd(1.4), rnd(1.2)+0.4, rnd(1.4), 0.13F, 0.55F, 0.36F, 155, 16, 18, 185, false);
            if (kind == 2) for (int i = 0; i < 5; i++) addSpark(x, y, z, rnd(3.2), rnd(2.8)+1.0, rnd(3.2), 0.14F, 255, 235, 170);
        } else if (kind == 3) { // Soft gunsmoke plume
            for (int i = 0; i < 3; i++) addPuff(x, y, z, rnd(0.3), 0.25+Math.random()*0.25, rnd(0.3), 0.10F, 0.55F, 0.45F, 200, 204, 210, 95, false);
        } else if (kind == 4) { // RPG launch smoke & flash
            for (int i = 0; i < 12; i++) addPuff(x, y, z, rnd(1.4), rnd(0.9)+0.4, rnd(1.4), 0.28F, 1.3F, 1.1F, 215, 212, 205, 175, false);
            for (int i = 0; i < 6; i++) addPuff(x, y, z, rnd(1.0), rnd(0.8), rnd(1.0), 0.24F, 0.9F, 0.22F, 255, 165, 50, 230, true);
        } else if (kind == 5) { // RPG massive smooth explosion fireball + billowing smoke + embers
            for (int i = 0; i < 18; i++) addPuff(x+rnd(0.9), y+rnd(0.9), z+rnd(0.9), rnd(3.5), Math.random()*3.8+0.6, rnd(3.5), 0.65F, 2.8F, 0.48F, 255, 150, 35, 235, true);
            for (int i = 0; i < 26; i++) addPuff(x+rnd(1.2), y+rnd(1.0), z+rnd(1.2), rnd(2.8), Math.random()*3.2+0.8, rnd(2.8), 0.85F, 2.4F, 2.1F, 72, 70, 68, 195, false);
            for (int i = 0; i < 24; i++) addSpark(x, y+0.3, z, rnd(7.5), Math.random()*7.5+1.5, rnd(7.5), 0.45F+(float)Math.random()*0.35F, 255, 185, 70);
        }
    }

    public static void spawnRocketTrail(double x, double y, double z, double vx, double vy, double vz) {
        addPuff(x-vx*0.18, y-vy*0.18, z-vz*0.18, rnd(0.35), rnd(0.35), rnd(0.35), 0.22F, 0.35F, 0.14F, 255, 175, 45, 235, true);
        addPuff(x-vx*0.32, y-vy*0.32, z-vz*0.32, rnd(0.45), 0.25+rnd(0.3), rnd(0.45), 0.28F, 1.15F, 1.05F, 222, 222, 222, 165, false);
    }

    public static void spawnBulletWisp(double x, double y, double z) {
        addPuff(x, y, z, 0, 0.08, 0, 0.045F, 0.18F, 0.18F, 225, 228, 235, 70, false);
    }

    private static void addSpark(double x,double y,double z,double vx,double vy,double vz,float max,int r,int g,int b) {
        if (SPARKS.size() >= 180) SPARKS.remove(0);
        SPARKS.add(new Spark(x,y,z,vx,vy,vz,max,r,g,b));
    }
    private static void addPuff(double x,double y,double z,double vx,double vy,double vz,float sz,float grow,float max,int r,int g,int b,int a0,boolean br) {
        if (PUFFS.size() >= 220) PUFFS.remove(0);
        PUFFS.add(new Puff(x,y,z,vx,vy,vz,sz,grow,max,r,g,b,a0,br));
    }

    public static void spawnShell(Vec3 pos, Vec3 right, Vec3 up, Vec3 look, boolean shotgun) {
        if (SHELLS.size() >= 90) SHELLS.remove(0);
        double sp = 1.9 + Math.random() * 0.9;
        Vec3 v = right.scale(sp).add(up.scale(1.1 + Math.random() * 0.6)).add(look.scale(-0.3 + rnd(0.25)));
        SHELLS.add(new Shell(pos.x, pos.y, pos.z, v.x, v.y, v.z, shotgun));
    }

    public static void spawnTracer(Vec3 a, Vec3 b) {
        if (TRACERS.size() >= 36) TRACERS.remove(0);
        TRACERS.add(new Tracer(a, b));
    }

    public static void render(PoseStack ps, Camera cam, float pt) {
        Minecraft mc = Minecraft.getInstance();
        Level lvl = mc.level;
        if (lvl == null) return;
        long now = System.nanoTime();
        float dt = Math.min(0.05F, (now - lastNano) / 1_000_000_000.0F);
        lastNano = now;

        Vec3 cp = cam.getPosition();
        MultiBufferSource.BufferSource bs = mc.renderBuffers().bufferSource();

        // 1. 3D Bullet Holes on Blocks
        if (!HOLES.isEmpty()) {
            VertexConsumer vc = bs.getBuffer(RenderType.entityTranslucent(HOLE_TEX));
            Iterator<Hole> it = HOLES.iterator();
            while (it.hasNext()) {
                Hole h = it.next(); h.age += dt;
                if (h.age > 26F) { it.remove(); continue; }
                int al = h.age > 22F ? (int)(255 * (1F - (h.age - 22F) / 4F)) : 255;
                int lt = LevelRenderer.getLightColor(lvl, BlockPos.containing(h.x+h.d.getStepX()*0.1, h.y+h.d.getStepY()*0.1, h.z+h.d.getStepZ()*0.1));
                ps.pushPose();
                ps.translate(h.x-cp.x+h.d.getStepX()*0.007, h.y-cp.y+h.d.getStepY()*0.007, h.z-cp.z+h.d.getStepZ()*0.007);
                switch (h.d) {
                    case UP -> ps.mulPose(Axis.XP.rotationDegrees(-90));
                    case DOWN -> ps.mulPose(Axis.XP.rotationDegrees(90));
                    case NORTH -> ps.mulPose(Axis.YP.rotationDegrees(180));
                    case EAST -> ps.mulPose(Axis.YP.rotationDegrees(90));
                    case WEST -> ps.mulPose(Axis.YP.rotationDegrees(-90));
                    default -> {}
                }
                ps.mulPose(Axis.ZP.rotationDegrees(h.roll));
                PoseStack.Pose p = ps.last(); Matrix4f m = p.pose(); Matrix3f n = p.normal();
                float r = 0.088F;
                vc.vertex(m,-r,-r,0).color(255,255,255,al).uv(0,1).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(lt).normal(n,0,0,1).endVertex();
                vc.vertex(m, r,-r,0).color(255,255,255,al).uv(1,1).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(lt).normal(n,0,0,1).endVertex();
                vc.vertex(m, r, r,0).color(255,255,255,al).uv(1,0).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(lt).normal(n,0,0,1).endVertex();
                vc.vertex(m,-r, r,0).color(255,255,255,al).uv(0,0).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(lt).normal(n,0,0,1).endVertex();
                ps.popPose();
            }
            bs.endBatch(RenderType.entityTranslucent(HOLE_TEX));
        }

        // 2. 3D Spinning Brass Shells, Glowing Hot Impact Spark Streaks & Bullet Tracers
        if (!SHELLS.isEmpty() || !SPARKS.isEmpty() || !TRACERS.isEmpty()) {
            VertexConsumer vc = bs.getBuffer(RenderType.entityCutoutNoCull(GunModelGeometry.ATLAS));
            Iterator<Shell> sit = SHELLS.iterator();
            while (sit.hasNext()) {
                Shell s = sit.next(); s.age += dt;
                if (s.age > 5F) { sit.remove(); continue; }
                s.vy -= 14.0 * dt;
                double nx = s.x + s.vx * dt, ny = s.y + s.vy * dt, nz = s.z + s.vz * dt;
                if (lvl.getBlockState(BlockPos.containing(nx, ny - 0.03, nz)).blocksMotion()) {
                    s.vy = -s.vy * 0.35; s.vx *= 0.52; s.vz *= 0.52; s.vrx *= 0.35F; s.vry *= 0.35F;
                } else { s.x = nx; s.y = ny; s.z = nz; }
                s.rx += s.vrx * dt; s.ry += s.vry * dt;
                int lt = LevelRenderer.getLightColor(lvl, BlockPos.containing(s.x, s.y, s.z));
                ps.pushPose();
                ps.translate(s.x - cp.x, s.y - cp.y, s.z - cp.z);
                ps.mulPose(Axis.YP.rotationDegrees(s.ry));
                ps.mulPose(Axis.XP.rotationDegrees(s.rx));
                if (s.sh) {
                    GunModelGeometry.cyl(ps, vc, lt, OverlayTexture.NO_OVERLAY, GunModelGeometry.T_RED_HULL, 0,0,0.4F, 0.38F,0.38F,1.5F, 2);
                    GunModelGeometry.cyl(ps, vc, lt, OverlayTexture.NO_OVERLAY, GunModelGeometry.T_BRASS, 0,0,-0.55F, 0.40F,0.40F,0.55F, 2);
                } else {
                    GunModelGeometry.cyl(ps, vc, lt, OverlayTexture.NO_OVERLAY, GunModelGeometry.T_BRASS, 0,0,0, 0.22F,0.22F,1.1F, 2);
                }
                ps.popPose();
            }

            Iterator<Spark> spit = SPARKS.iterator();
            while (spit.hasNext()) {
                Spark sp = spit.next(); sp.age += dt;
                if (sp.age > sp.max) { spit.remove(); continue; }
                sp.vy -= 13.5 * dt;
                double nx = sp.x + sp.vx * dt, ny = sp.y + sp.vy * dt, nz = sp.z + sp.vz * dt;
                if (lvl.getBlockState(BlockPos.containing(nx, ny, nz)).blocksMotion()) { sp.vy = -sp.vy * 0.4; sp.vx *= 0.5; sp.vz *= 0.5; }
                else { sp.x = nx; sp.y = ny; sp.z = nz; }
                double spd = Math.sqrt(sp.vx*sp.vx + sp.vy*sp.vy + sp.vz*sp.vz);
                if (spd < 0.1) continue;
                double hz = Math.sqrt(sp.vx*sp.vx + sp.vz*sp.vz);
                ps.pushPose();
                ps.translate(sp.x - cp.x, sp.y - cp.y, sp.z - cp.z);
                ps.mulPose(Axis.YP.rotationDegrees((float)(Math.atan2(sp.vx, sp.vz) * 180.0 / Math.PI)));
                ps.mulPose(Axis.XP.rotationDegrees(-(float)(Math.atan2(sp.vy, hz) * 180.0 / Math.PI)));
                float len = (float)Math.min(4.2, spd * 0.9);
                GunModelGeometry.box(ps, vc, LightTexture.FULL_BRIGHT, OverlayTexture.NO_OVERLAY, GunModelGeometry.T_FLASH, 0,0,-len*0.4F, 0.16F,0.16F,len);
                ps.popPose();
            }

            Iterator<Tracer> tit = TRACERS.iterator();
            while (tit.hasNext()) {
                Tracer tr = tit.next(); tr.age += dt;
                if (tr.age > 0.055F) { tit.remove(); continue; }
                Vec3 dir = tr.b.subtract(tr.a);
                double len = Math.min(26.0, dir.length());
                if (len < 0.25) continue;
                Vec3 d = dir.normalize();
                double hz = Math.sqrt(d.x*d.x + d.z*d.z);
                Vec3 mid = tr.a.add(d.scale(len * 0.5));
                ps.pushPose();
                ps.translate(mid.x - cp.x, mid.y - cp.y, mid.z - cp.z);
                ps.mulPose(Axis.YP.rotationDegrees((float)(Math.atan2(d.x, d.z) * 180.0 / Math.PI)));
                ps.mulPose(Axis.XP.rotationDegrees(-(float)(Math.atan2(d.y, hz) * 180.0 / Math.PI)));
                GunModelGeometry.box(ps, vc, LightTexture.FULL_BRIGHT, OverlayTexture.NO_OVERLAY, GunModelGeometry.T_FLASH, 0,0,0, 0.22F,0.22F,(float)(len * 32.0));
                ps.popPose();
            }
            bs.endBatch(RenderType.entityCutoutNoCull(GunModelGeometry.ATLAS));
        }

        // 3. Soft Volumetric Smoke, Dust, Rocket Exhaust, Explosion Fire & Hit Mist
        if (!PUFFS.isEmpty()) {
            VertexConsumer vc = bs.getBuffer(RenderType.entityTranslucent(PUFF_TEX));
            Quaternionf camRot = cam.rotation();
            Iterator<Puff> pit = PUFFS.iterator();
            while (pit.hasNext()) {
                Puff pf = pit.next(); pf.age += dt;
                if (pf.age > pf.max) { pit.remove(); continue; }
                pf.x += pf.vx * dt; pf.y += pf.vy * dt; pf.z += pf.vz * dt;
                pf.vx *= Math.exp(-dt * 2.5); pf.vy *= Math.exp(-dt * 1.8); pf.vz *= Math.exp(-dt * 2.5);
                float t = pf.age / pf.max;
                float r = pf.sz + pf.grow * t;
                int al = (int)(pf.a0 * (1F - t) * (1F - t));
                int lt = pf.bright ? LightTexture.FULL_BRIGHT : LevelRenderer.getLightColor(lvl, BlockPos.containing(pf.x, pf.y, pf.z));
                ps.pushPose();
                ps.translate(pf.x - cp.x, pf.y - cp.y, pf.z - cp.z);
                ps.mulPose(camRot);
                PoseStack.Pose p = ps.last(); Matrix4f m = p.pose(); Matrix3f n = p.normal();
                vc.vertex(m,-r,-r,0).color(pf.r,pf.g,pf.b,al).uv(0,1).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(lt).normal(n,0,0,1).endVertex();
                vc.vertex(m, r,-r,0).color(pf.r,pf.g,pf.b,al).uv(1,1).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(lt).normal(n,0,0,1).endVertex();
                vc.vertex(m, r, r,0).color(pf.r,pf.g,pf.b,al).uv(1,0).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(lt).normal(n,0,0,1).endVertex();
                vc.vertex(m,-r, r,0).color(pf.r,pf.g,pf.b,al).uv(0,0).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(lt).normal(n,0,0,1).endVertex();
                ps.popPose();
            }
            bs.endBatch(RenderType.entityTranslucent(PUFF_TEX));
        }
    }
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/entity/BulletEntity.java"
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
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.DistExecutor;
import net.minecraftforge.network.PacketDistributor;

public class BulletEntity extends ThrowableProjectile {
    private float damage = 15.0F, armorPen = 0.4F;

    public BulletEntity(EntityType<? extends BulletEntity> t, Level l) { super(t, l); }
    public BulletEntity(Level l, LivingEntity s, float dmg, float pen) {
        super(ModEntities.BULLET.get(), s, l);
        this.damage = dmg; this.armorPen = pen;
    }

    @Override protected void defineSynchedData() {}
    @Override protected float getGravity() { return 0.004F; }

    @Override
    public void tick() {
        super.tick();
        if (this.level().isClientSide && this.tickCount % 2 == 0) {
            double px = getX(), py = getY(), pz = getZ();
            DistExecutor.unsafeRunWhenOn(Dist.CLIENT, () -> () -> com.arsenalmod.client.WorldEffectsRenderer.spawnBulletWisp(px, py, pz));
        }
        if (this.tickCount > 70) this.discard();
    }

    @Override
    protected void onHitEntity(EntityHitResult res) {
        super.onHitEntity(res);
        Entity target = res.getEntity(), owner = this.getOwner();
        if (target == owner || this.level().isClientSide) return;

        double relY = (res.getLocation().y - target.getY()) / Math.max(0.2, target.getBbHeight());
        boolean hs = relY >= 0.72;
        float finalDmg = this.damage * (hs ? 2.2F : (relY < 0.32 ? 0.78F : 1.0F));
        if (target instanceof LivingEntity lv && lv.getArmorValue() > 0) {
            finalDmg *= (1.0F + this.armorPen * (lv.getArmorValue() / 16.0F));
        }

        target.invulnerableTime = 0;
        boolean hurt = target.hurt(this.damageSources().thrown(this, owner), finalDmg);
        boolean killed = target instanceof LivingEntity lv && lv.isDeadOrDying();

        if (hurt && owner instanceof ServerPlayer sp) {
            ModNetwork.INSTANCE.send(PacketDistributor.PLAYER.with(() -> sp), new S2CHitmarkerPacket(hs, killed));
            sp.playNotifySound(hs ? SoundEvents.EXPERIENCE_ORB_PICKUP : SoundEvents.ARROW_HIT_PLAYER,
                    SoundSource.PLAYERS, 0.7F, hs ? 1.9F : 1.4F);
        }
        if (this.level() instanceof ServerLevel sl) {
            Vec3 h = res.getLocation();
            ModNetwork.INSTANCE.send(
                    PacketDistributor.NEAR.with(() -> new PacketDistributor.TargetPoint(h.x, h.y, h.z, 96.0, sl.dimension())),
                    new S2CImpactPacket(h.x, h.y, h.z, hs ? 2 : 1, 0)
            );
        }
        this.discard();
    }

    @Override
    protected void onHitBlock(BlockHitResult res) {
        super.onHitBlock(res);
        if (!this.level().isClientSide && this.level() instanceof ServerLevel sl) {
            Vec3 h = res.getLocation();
            BlockState st = sl.getBlockState(res.getBlockPos());
            sl.sendParticles(new BlockParticleOption(ParticleTypes.BLOCK, st), h.x, h.y, h.z, 5, 0.04, 0.04, 0.04, 0.14);
            sl.playSound(null, h.x, h.y, h.z, st.getSoundType().getHitSound(), SoundSource.BLOCKS, 0.65F, 1.55F);
            ModNetwork.INSTANCE.send(
                    PacketDistributor.NEAR.with(() -> new PacketDistributor.TargetPoint(h.x, h.y, h.z, 96.0, sl.dimension())),
                    new S2CImpactPacket(h.x, h.y, h.z, 0, res.getDirection().get3DDataValue())
            );
            this.discard();
        }
    }
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/entity/RocketEntity.java"
package com.arsenalmod.entity;

import com.arsenalmod.network.*;
import com.arsenalmod.registry.ModEntities;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.*;
import net.minecraft.world.entity.projectile.ThrowableProjectile;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.*;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.DistExecutor;
import net.minecraftforge.network.PacketDistributor;

public class RocketEntity extends ThrowableProjectile {
    private float dmg = 85.0F;
    public RocketEntity(EntityType<? extends RocketEntity> t, Level l) { super(t, l); }
    public RocketEntity(Level l, LivingEntity s, float dmg) { super(ModEntities.ROCKET.get(), s, l); this.dmg = dmg; }

    @Override protected void defineSynchedData() {}
    @Override protected float getGravity() { return 0.007F; }

    @Override
    public void tick() {
        super.tick();
        if (this.level().isClientSide) {
            Vec3 m = getDeltaMovement();
            double x = getX(), y = getY(), z = getZ();
            DistExecutor.unsafeRunWhenOn(Dist.CLIENT, () -> () ->
                    com.arsenalmod.client.WorldEffectsRenderer.spawnRocketTrail(x, y, z, m.x, m.y, m.z));
        }
        if (this.tickCount > 120) boom();
    }

    private void boom() {
        if (!this.level().isClientSide && this.level() instanceof ServerLevel sl) {
            ModNetwork.INSTANCE.send(
                    PacketDistributor.NEAR.with(() -> new PacketDistributor.TargetPoint(getX(), getY(), getZ(), 128.0, sl.dimension())),
                    new S2CImpactPacket(getX(), getY(), getZ(), 5, 0)
            );
            sl.explode(this, getX(), getY(), getZ(), 5.5F, Level.ExplosionInteraction.TNT);
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
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/item/GunItem.java"
package com.arsenalmod.item;

import com.arsenalmod.client.*;
import com.arsenalmod.registry.ModItems;
import com.mojang.blaze3d.vertex.PoseStack;
import net.minecraft.ChatFormatting;
import net.minecraft.client.model.HumanoidModel;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.client.renderer.BlockEntityWithoutLevelRenderer;
import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.chat.Component;
import net.minecraft.sounds.*;
import net.minecraft.util.Mth;
import net.minecraft.world.*;
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
            p.level().playSound(null, p.getX(), p.getY(), p.getZ(), SoundEvents.DISPENSER_FAIL, SoundSource.PLAYERS, 0.55F, 1.55F);
            return;
        }
        CompoundTag t = s.getOrCreateTag();
        t.putBoolean(TAG_REL, true); t.putLong(TAG_RS, now); t.putLong(TAG_RE, now + type.reloadTicks);
        p.level().playSound(null, p.getX(), p.getY(), p.getZ(), SoundEvents.IRON_TRAPDOOR_OPEN, SoundSource.PLAYERS, 0.45F, 1.9F);
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
                lvl.playSound(null, p.getX(), p.getY(), p.getZ(), SoundEvents.PISTON_CONTRACT, SoundSource.PLAYERS, 0.5F, 1.95F);
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
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/item/GunType.java"
package com.arsenalmod.item;

public enum GunType {
    GLOCK19("glock19", "Glock 19", 12.0F, 0.25F, 5, 17, 34, false, 1, 1.0F, 6.2F,
            0.055F, 5.2F, 1.0F, 0.86F, false, false, false, AmmoKind.PISTOL, 17,
            0.26F, -0.22F, -0.56F, -0.44F, 3.85F, -9.2F, 2.3F),
    AK47("ak47", "AK-47", 17.5F, 0.50F, 3, 30, 48, true, 1, 1.5F, 7.0F,
            0.075F, 4.2F, 1.2F, 0.76F, false, false, false, AmmoKind.RIFLE, 15,
            0.29F, -0.24F, -0.68F, -0.52F, 4.55F, -25.8F, 1.6F),
    M4A1("m4a1", "M4A1 Tatica", 14.5F, 0.40F, 2, 30, 44, true, 1, 0.8F, 7.4F,
            0.050F, 2.5F, 0.65F, 0.70F, false, false, false, AmmoKind.RIFLE, 15,
            0.29F, -0.24F, -0.68F, -0.52F, 5.45F, -27.2F, 1.8F),
    SPAS12("spas12", "SPAS-12", 6.8F, 0.22F, 16, 8, 54, false, 10, 5.8F, 5.6F,
            0.135F, 11.5F, 3.3F, 0.84F, false, false, true, AmmoKind.SHOTGUN, 1,
            0.30F, -0.25F, -0.70F, -0.55F, 4.30F, -24.2F, 2.1F),
    AWP_SNIPER("awp_sniper", "AWP Sniper", 58.0F, 0.85F, 28, 5, 58, false, 1, 0.05F, 11.0F,
            0.145F, 13.5F, 3.8F, 0.20F, false, true, false, AmmoKind.SNIPER, 1,
            0.30F, -0.25F, -0.74F, -0.52F, 5.85F, -33.5F, 2.0F),
    MINIGUN("minigun", "M134 Minigun", 11.5F, 0.48F, 1, 200, 68, true, 1, 2.6F, 7.0F,
            0.038F, 1.4F, 0.42F, 0.85F, false, false, false, AmmoKind.RIFLE, 40,
            0.34F, -0.38F, -0.78F, -0.68F, 4.40F, -26.5F, 0.8F),
    RPG7("rpg7", "RPG-7", 85.0F, 0.95F, 30, 1, 64, false, 1, 0.25F, 3.0F,
            0.165F, 14.0F, 4.5F, 0.74F, true, false, false, AmmoKind.ROCKET, 1,
            0.34F, -0.24F, -0.82F, -0.68F, 5.40F, -28.0F, 2.2F);

    public enum AmmoKind { PISTOL, RIFLE, SHOTGUN, SNIPER, ROCKET }

    public final String id, displayName;
    public final float damage, armorPen, spread, bulletSpeed, recoilKick, recoilPitch, cameraKick, adsFov;
    public final float hipX, hipY, hipZ, adsZ, sightU, muzzleZ, muzzleY;
    public final int fireCooldown, maxAmmo, reloadTicks, pellets, roundsPerAmmoItem;
    public final boolean fullAuto, isRocket, isSniper, isShotgun;
    public final AmmoKind ammoKind;

    GunType(String id, String displayName, float damage, float armorPen, int fireCooldown, int maxAmmo,
            int reloadTicks, boolean fullAuto, int pellets, float spread, float bulletSpeed,
            float recoilKick, float recoilPitch, float cameraKick, float adsFov,
            boolean isRocket, boolean isSniper, boolean isShotgun, AmmoKind ammoKind, int roundsPerAmmoItem,
            float hipX, float hipY, float hipZ, float adsZ, float sightU, float muzzleZ, float muzzleY) {
        this.id = id; this.displayName = displayName; this.damage = damage; this.armorPen = armorPen;
        this.fireCooldown = fireCooldown; this.maxAmmo = maxAmmo; this.reloadTicks = reloadTicks;
        this.fullAuto = fullAuto; this.pellets = pellets; this.spread = spread; this.bulletSpeed = bulletSpeed;
        this.recoilKick = recoilKick; this.recoilPitch = recoilPitch; this.cameraKick = cameraKick;
        this.adsFov = adsFov; this.isRocket = isRocket; this.isSniper = isSniper; this.isShotgun = isShotgun;
        this.ammoKind = ammoKind; this.roundsPerAmmoItem = roundsPerAmmoItem;
        this.hipX = hipX; this.hipY = hipY; this.hipZ = hipZ; this.adsZ = adsZ;
        this.sightU = sightU; this.muzzleZ = muzzleZ; this.muzzleY = muzzleY;
    }
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/network/C2SReloadPacket.java"
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
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/network/C2SShootPacket.java"
package com.arsenalmod.network;

import com.arsenalmod.entity.*;
import com.arsenalmod.item.*;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.*;
import net.minecraft.sounds.*;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.network.*;
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
        float spread = msg.aiming ? t.spread * 0.2F : t.spread;

        if (t.isRocket) {
            RocketEntity r = new RocketEntity(lvl, p, t.damage);
            Vec3 sp = eye.add(look.scale(1.0));
            r.setPos(sp.x, sp.y - 0.06, sp.z);
            r.shoot(look.x, look.y, look.z, t.bulletSpeed, spread);
            lvl.addFreshEntity(r);
        } else {
            for (int i = 0; i < t.pellets; i++) {
                BulletEntity b = new BulletEntity(lvl, p, t.damage, t.armorPen);
                Vec3 sp = eye.add(look.scale(0.55));
                b.setPos(sp.x, sp.y - 0.04, sp.z);
                b.shoot(look.x, look.y, look.z, t.bulletSpeed, spread);
                lvl.addFreshEntity(b);
            }
        }
        sound(lvl, p, t);
        Vec3 mz = eye.add(look.scale(1.15));
        ModNetwork.INSTANCE.send(
                PacketDistributor.NEAR.with(() -> new PacketDistributor.TargetPoint(mz.x, mz.y, mz.z, 64.0, lvl.dimension())),
                new S2CImpactPacket(mz.x, mz.y - 0.08, mz.z, t.isRocket ? 4 : 3, 0)
        );
    }

    private static void sound(ServerLevel l, ServerPlayer p, GunType t) {
        double x = p.getX(), y = p.getY(), z = p.getZ();
        switch (t) {
            case GLOCK19 -> { l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_BLAST,SoundSource.PLAYERS,1.0F,1.88F); l.playSound(null,x,y,z,SoundEvents.GENERIC_EXPLODE,SoundSource.PLAYERS,0.2F,2.0F); }
            case AK47 -> { l.playSound(null,x,y,z,SoundEvents.GENERIC_EXPLODE,SoundSource.PLAYERS,0.58F,1.32F); l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_BLAST,SoundSource.PLAYERS,1.1F,1.12F); }
            case M4A1 -> { l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_BLAST,SoundSource.PLAYERS,0.72F,1.72F); l.playSound(null,x,y,z,SoundEvents.IRON_TRAPDOOR_CLOSE,SoundSource.PLAYERS,0.52F,1.95F); }
            case SPAS12 -> { l.playSound(null,x,y,z,SoundEvents.GENERIC_EXPLODE,SoundSource.PLAYERS,1.0F,0.84F); l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_LARGE_BLAST,SoundSource.PLAYERS,1.15F,0.82F); }
            case AWP_SNIPER -> { l.playSound(null,x,y,z,SoundEvents.GENERIC_EXPLODE,SoundSource.PLAYERS,1.3F,0.68F); l.playSound(null,x,y,z,SoundEvents.LIGHTNING_BOLT_THUNDER,SoundSource.PLAYERS,0.38F,2.0F); }
            case MINIGUN -> { l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_BLAST,SoundSource.PLAYERS,0.75F,1.35F); l.playSound(null,x,y,z,SoundEvents.PISTON_EXTEND,SoundSource.PLAYERS,0.35F,2.0F); }
            case RPG7 -> { l.playSound(null,x,y,z,SoundEvents.FIREWORK_ROCKET_LAUNCH,SoundSource.PLAYERS,1.65F,0.58F); l.playSound(null,x,y,z,SoundEvents.GENERIC_EXPLODE,SoundSource.PLAYERS,0.9F,0.65F); }
        }
    }
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/network/ModNetwork.java"
package com.arsenalmod.network;

import com.arsenalmod.ArsenalMod;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.network.*;
import net.minecraftforge.network.simple.SimpleChannel;

public class ModNetwork {
    private static final String V = "3";
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
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/network/S2CHitmarkerPacket.java"
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
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/network/S2CImpactPacket.java"
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
    public final int kind, dir; // 0=block, 1=body, 2=headshot, 3=muzzle, 4=rpgLaunch, 5=rpgBoom
    public S2CImpactPacket(double x, double y, double z, int kind, int dir) {
        this.x = x; this.y = y; this.z = z; this.kind = kind; this.dir = dir;
    }
    public static void encode(S2CImpactPacket m, FriendlyByteBuf b) {
        b.writeDouble(m.x); b.writeDouble(m.y); b.writeDouble(m.z); b.writeByte(m.kind); b.writeByte(m.dir);
    }
    public static S2CImpactPacket decode(FriendlyByteBuf b) {
        return new S2CImpactPacket(b.readDouble(), b.readDouble(), b.readDouble(), b.readByte(), b.readByte());
    }
    public static void handle(S2CImpactPacket m, Supplier<NetworkEvent.Context> ctx) {
        DistExecutor.unsafeRunWhenOn(Dist.CLIENT, () -> () ->
                WorldEffectsRenderer.handleFx(m.x, m.y, m.z, m.kind, Direction.from3DDataValue(m.dir)));
    }
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/registry/ModCreativeTabs.java"
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
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/registry/ModEntities.java"
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
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/java/com/arsenalmod/registry/ModItems.java"
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
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/META-INF/mods.toml"
modLoader="javafml"
loaderVersion="[47,)"
license="MIT"
[[mods]]
modId="arsenalmod"
version="3.0.0"
displayName="Arsenal 3D v3"
description='''Armas 3D de alta precisao, animacoes detalhadas, particulas proprias e balistica realista.'''
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
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/lang/en_us.json"
{
  "itemGroup.arsenalmod.arsenal_tab": "Arsenal 3D - Armas",
  "item.arsenalmod.glock19": "Glock 19 (9mm)",
  "item.arsenalmod.ak47": "AK-47 (7.62mm)",
  "item.arsenalmod.m4a1": "M4A1 Tatica (5.56mm)",
  "item.arsenalmod.spas12": "SPAS-12 (Cal. 12)",
  "item.arsenalmod.awp_sniper": "AWP Sniper (.338)",
  "item.arsenalmod.minigun": "M134 Minigun",
  "item.arsenalmod.rpg7": "RPG-7 (PG-7V)",
  "item.arsenalmod.pistol_ammo": "Municao 9mm",
  "item.arsenalmod.rifle_ammo": "Municao de Fuzil",
  "item.arsenalmod.shotgun_shell": "Cartucho Calibre 12",
  "item.arsenalmod.sniper_ammo": "Municao .338 Lapua",
  "item.arsenalmod.rocket_ammo": "Foguete PG-7V",
  "key.categories.arsenalmod": "Arsenal 3D",
  "key.arsenalmod.reload": "Recarregar Arma"
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/lang/pt_br.json"
{
  "itemGroup.arsenalmod.arsenal_tab": "Arsenal 3D - Armas",
  "item.arsenalmod.glock19": "Glock 19 (9mm)",
  "item.arsenalmod.ak47": "AK-47 (7.62mm)",
  "item.arsenalmod.m4a1": "M4A1 Tatica (5.56mm)",
  "item.arsenalmod.spas12": "SPAS-12 (Cal. 12)",
  "item.arsenalmod.awp_sniper": "AWP Sniper (.338)",
  "item.arsenalmod.minigun": "M134 Minigun",
  "item.arsenalmod.rpg7": "RPG-7 (PG-7V)",
  "item.arsenalmod.pistol_ammo": "Municao 9mm",
  "item.arsenalmod.rifle_ammo": "Municao de Fuzil",
  "item.arsenalmod.shotgun_shell": "Cartucho Calibre 12",
  "item.arsenalmod.sniper_ammo": "Municao .338 Lapua",
  "item.arsenalmod.rocket_ammo": "Foguete PG-7V",
  "key.categories.arsenalmod": "Arsenal 3D",
  "key.arsenalmod.reload": "Recarregar Arma"
}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/ak47.json"
{"parent":"builtin/entity","gui_light":"side","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/awp_sniper.json"
{"parent":"builtin/entity","gui_light":"side","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/glock19.json"
{"parent":"builtin/entity","gui_light":"side","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/m4a1.json"
{"parent":"builtin/entity","gui_light":"side","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/minigun.json"
{"parent":"builtin/entity","gui_light":"side","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/pistol_ammo.json"
{"parent":"minecraft:item/generated","textures":{"layer0":"arsenalmod:item/pistol_ammo"}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/rifle_ammo.json"
{"parent":"minecraft:item/generated","textures":{"layer0":"arsenalmod:item/rifle_ammo"}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/rocket_ammo.json"
{"parent":"minecraft:item/generated","textures":{"layer0":"arsenalmod:item/rocket_ammo"}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/rpg7.json"
{"parent":"builtin/entity","gui_light":"side","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/shotgun_shell.json"
{"parent":"minecraft:item/generated","textures":{"layer0":"arsenalmod:item/shotgun_shell"}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/sniper_ammo.json"
{"parent":"minecraft:item/generated","textures":{"layer0":"arsenalmod:item/sniper_ammo"}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/assets/arsenalmod/models/item/spas12.json"
{"parent":"builtin/entity","gui_light":"side","display":{"firstperson_righthand":{"scale":[1,1,1]},"firstperson_lefthand":{"scale":[1,1,1]},"thirdperson_righthand":{"scale":[1,1,1]},"thirdperson_lefthand":{"scale":[1,1,1]},"gui":{"scale":[1,1,1]},"ground":{"scale":[1,1,1]},"fixed":{"scale":[1,1,1]}}}
ARSENAL_V3_EOF

cat << 'ARSENAL_V3_EOF' > "src/main/resources/pack.mcmeta"
{
  "pack": {
    "description": "Arsenal 3D v3",
    "pack_format": 15
  }
}
ARSENAL_V3_EOF


echo "[4/5] Gerando texturas lisas de metal/madeira, bullet_hole 64x64, fumaca suave e icones 32x32..."
cat << 'TEX_V3_EOF' > TextureGen.java
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.zip.*;

public class TextureGen {
    static void writePng(String path, int w, int h, int[] rgba) throws Exception {
        File f = new File(path); f.getParentFile().mkdirs();
        try (DataOutputStream out = new DataOutputStream(new FileOutputStream(f))) {
            out.write(new byte[]{(byte)137,80,78,71,13,10,26,10});
            ByteArrayOutputStream ihdr = new ByteArrayOutputStream();
            DataOutputStream id = new DataOutputStream(ihdr);
            id.writeInt(w); id.writeInt(h); id.writeByte(8); id.writeByte(6); id.writeByte(0); id.writeByte(0); id.writeByte(0);
            chunk(out, "IHDR", ihdr.toByteArray());
            ByteArrayOutputStream raw = new ByteArrayOutputStream();
            try (DeflaterOutputStream def = new DeflaterOutputStream(raw)) {
                for (int y = 0; y < h; y++) {
                    def.write(0);
                    for (int x = 0; x < w; x++) {
                        int p = rgba[y * w + x];
                        def.write((p >> 16) & 255); def.write((p >> 8) & 255); def.write(p & 255); def.write((p >>> 24) & 255);
                    }
                }
            }
            chunk(out, "IDAT", raw.toByteArray());
            chunk(out, "IEND", new byte[0]);
        }
    }
    static void chunk(DataOutputStream o, String t, byte[] d) throws Exception {
        byte[] tb = t.getBytes(StandardCharsets.US_ASCII);
        o.writeInt(d.length); o.write(tb); o.write(d);
        CRC32 c = new CRC32(); c.update(tb); c.update(d); o.writeInt((int)c.getValue());
    }
    static int c(int r, int g, int b, int a) {
        return ((Math.max(0,Math.min(255,a)))<<24)|((Math.max(0,Math.min(255,r)))<<16)|((Math.max(0,Math.min(255,g)))<<8)|Math.max(0,Math.min(255,b));
    }

    public static void main(String[] args) throws Exception {
        // 1. Seamless Clean Borderless Material Atlas (ZERO ugly borders, ZERO blotchy noise!)
        int[] a = new int[256 * 256];
        for (int tile = 0; tile < 20; tile++) {
            int ox = (tile % 8) * 32, oy = (tile / 8) * 32;
            for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) {
                double brush = Math.sin(y * 1.4 + x * 0.08) * 4.0;
                double sheen = Math.sin((y / 31.0) * Math.PI) * 14.0;
                int px = switch (tile) {
                    case 0 -> c((int)(36+sheen*0.6+brush), (int)(40+sheen*0.6+brush), (int)(48+sheen*0.7+brush), 255); // Anodized Gunmetal
                    case 1 -> c((int)(72+sheen+brush), (int)(79+sheen+brush), (int)(90+sheen+brush), 255); // Parkerized Steel
                    case 2 -> { int s=(int)(Math.sin(y*0.28)*28); yield c(186+s, 194+s, 206+s, 255); } // Brushed Chrome
                    case 3 -> c((int)(25+sheen*0.35), (int)(27+sheen*0.35), (int)(32+sheen*0.4), 255); // Matte Polymer
                    case 4 -> { int k=((x+y)%4==0||(x-y+32)%4==0)?-6:5; yield c(26+k, 28+k, 32+k, 255); } // Fine Stippled Grip
                    case 5 -> { int sl=(y%6<2)?-14:10; yield c(38+sl, 42+sl, 48+sl, 255); } // Machined Picatinny
                    case 6 -> { int g=(int)(Math.sin(y*0.65+Math.sin(x*0.16)*1.8)*16 + Math.sin(y*0.18)*10); yield c(156+g, 82+g/2, 32+g/3, 255); } // AK Lacquered Birch
                    case 7 -> { int g=(int)(Math.sin(y*0.7+Math.sin(x*0.15)*1.5)*13); yield c(84+g, 46+g/2, 24+g/3, 255); } // Dark Walnut Wood
                    case 8 -> c((int)(70+sheen*0.5+brush*0.5), (int)(84+sheen*0.5+brush*0.5), (int)(50+sheen*0.4), 255); // Military Olive Drab
                    case 9 -> c((int)(148+sheen*0.4), (int)(128+sheen*0.4), (int)(96+sheen*0.3), 255); // Magpul FDE Tan
                    case 10 -> { int s=(int)(Math.sin(y*0.3)*26); yield c(218+s, 178+s, 62+s/2, 255); } // Polished Brass
                    case 11 -> { int gl=Math.abs(x-y)<5?55:0; yield c(20+gl, 92+gl, 172+gl, 255); } // Anti-Reflective Lens
                    case 12 -> c(255, 32, 42, 255); // Holographic Red
                    case 13 -> c(42, 255, 115, 255); // Tritium Green
                    case 14 -> { double d=Math.hypot(x-16,y-16); yield c(255, (int)Math.max(110,255-d*9), (int)Math.max(25,245-d*15), 255); } // Flash Plasma
                    case 15 -> c((int)(178+sheen*0.6), (int)(26+sheen*0.3), (int)(30+sheen*0.3), 255); // Red 12ga Hull
                    case 16 -> { int w=((x+y)%6==0)?5:-4; yield c(38+w, 41+w, 37+w, 255); } // Tactical Glove
                    case 17 -> { int cm=((x/7+y/6)%3==0)?10:-8; yield c(52+cm, 58+cm, 46+cm, 255); } // Combat Sleeve
                    case 18 -> { int cb=((x+y)%4<2)?7:-6; yield c(32+cb, 35+cb, 40+cb, 255); } // Carbon Fiber
                    default -> c(8, 9, 12, 255); // Pitch-Dark Hollow Bore Interior
                };
                a[(oy + y) * 256 + (ox + x)] = px;
            }
        }
        writePng("src/main/resources/assets/arsenalmod/textures/entity/weapons_atlas.png", 256, 256, a);

        // 2. Crisp 64x64 Bullet Hole Decal
        int[] bh = new int[64 * 64];
        for (int y = 0; y < 64; y++) for (int x = 0; x < 64; x++) {
            double dx = x - 31.5, dy = y - 31.5, d = Math.hypot(dx, dy), ang = Math.atan2(dy, dx);
            double cr = Math.pow(Math.abs(Math.sin(ang * 4.0 + 0.5)), 18.0) * 13.0
                      + Math.pow(Math.abs(Math.cos(ang * 2.5 - 0.3)), 14.0) * 8.0;
            if (d < 8.5) bh[y*64+x] = c(7, 7, 9, 250);
            else if (d < 13.5) bh[y*64+x] = c(30, 27, 25, (int)(225 - (d - 8.5) * 20));
            else if (d < 18.0 + cr) {
                int al = (int)Math.max(0, 145 * (1.0 - (d - 13.5) / (4.5 + cr)));
                bh[y*64+x] = c(46, 42, 40, al);
            }
        }
        writePng("src/main/resources/assets/arsenalmod/textures/entity/bullet_hole.png", 64, 64, bh);

        // 3. Ultra-Soft 32x32 Gaussian Radial Smoke/Fire/Mist Puff Texture
        int[] pf = new int[32 * 32];
        for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) {
            double d = Math.hypot(x - 15.5, y - 15.5) / 15.5;
            if (d < 1.0) {
                int al = (int)(255 * Math.pow(1.0 - d * d, 2.0));
                pf[y*32+x] = c(255, 255, 255, al);
            }
        }
        writePng("src/main/resources/assets/arsenalmod/textures/entity/smoke_puff.png", 32, 32, pf);

        // 4. Detailed 32x32 Outlined & Shaded Ammo Item Icons
        drawCartridges("pistol_ammo", 3, 212,172,58, 185,112,48, 12, 26);
        drawCartridges("rifle_ammo",  3, 220,180,62, 198,108,42, 6, 27);
        drawShotgun("shotgun_shell");
        drawCartridges("sniper_ammo", 2, 226,188,68, 212,126,48, 4, 28);
        drawRocket("rocket_ammo");
    }

    static void drawCartridges(String name, int count, int br, int bg, int bb, int tr, int tg, int tb, int yTop, int yBot) throws Exception {
        int[] p = new int[32 * 32];
        int w = count == 2 ? 7 : 6, gap = 2, total = count * w + (count - 1) * gap, sx = (32 - total) / 2;
        for (int i = 0; i < count; i++) {
            int x0 = sx + i * (w + gap), x1 = x0 + w;
            for (int y = yTop; y <= yBot; y++) for (int x = x0; x <= x1; x++) {
                double ny = (y - yTop) / (double)(yBot - yTop);
                int pad = ny < 0.28 ? (int)((0.28 - ny) / 0.28 * (w * 0.45)) : 0;
                if (x < x0 + pad || x > x1 - pad) continue;
                boolean out = (x == x0 + pad || x == x1 - pad || y == yTop || y == yBot);
                if (out) { p[y*32+x] = c(22, 18, 16, 255); continue; }
                int hi = (x - (x0 + pad) == 1) ? 35 : (x > x1 - pad - 2 ? -28 : 0);
                if (ny < 0.32) p[y*32+x] = c(tr+hi, tg+hi, tb+hi, 255);
                else if (y >= yBot - 2) p[y*32+x] = c(165+hi, 132+hi, 42+hi, 255);
                else p[y*32+x] = c(br+hi, bg+hi, bb+hi, 255);
            }
        }
        writePng("src/main/resources/assets/arsenalmod/textures/item/" + name + ".png", 32, 32, p);
    }

    static void drawShotgun(String name) throws Exception {
        int[] p = new int[32 * 32];
        for (int i = 0; i < 2; i++) {
            int x0 = 6 + i * 11, x1 = x0 + 8;
            for (int y = 6; y <= 26; y++) for (int x = x0; x <= x1; x++) {
                boolean out = (x == x0 || x == x1 || y == 6 || y == 26);
                if (out) { p[y*32+x] = c(25, 14, 14, 255); continue; }
                int hi = (x == x0 + 2) ? 40 : (x >= x1 - 2 ? -30 : 0);
                if (y >= 20) p[y*32+x] = c(220+hi, 182+hi, 64+hi, 255);
                else p[y*32+x] = c(192+hi, 28+hi/2, 34+hi/2, 255);
            }
        }
        writePng("src/main/resources/assets/arsenalmod/textures/item/" + name + ".png", 32, 32, p);
    }

    static void drawRocket(String name) throws Exception {
        int[] p = new int[32 * 32];
        for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) {
            double u = ((x - 16) + (16 - y)) * 0.707;
            double v = ((x - 16) - (16 - y)) * 0.707;
            double av = Math.abs(v);
            double rad = 0;
            int col = 0;
            if (u >= 11 && u < 16) { rad = 1.6 * (16 - u) / 5.0; col = c(220,180,62,255); }
            else if (u >= 4 && u < 11) { rad = 1.6 + 3.4 * (11 - u) / 7.0; col = c(74,94,52,255); }
            else if (u >= -1 && u < 4) { rad = 5.0 - 2.6 * (4 - u) / 5.0; col = (Math.abs(u - 2.5) < 0.9) ? c(222,182,58,255) : c(74,94,52,255); }
            else if (u >= -12 && u < -1) { rad = 1.5; col = c(96,104,114,255); }
            else if (u >= -15 && u < -12) { rad = 4.2; col = c(56,62,70,255); }
            if (rad > 0 && av <= rad) {
                if (av > rad - 1.1) p[y*32+x] = c(20, 22, 20, 255);
                else {
                    int hi = v < -rad * 0.25 ? 28 : (v > rad * 0.35 ? -24 : 0);
                    p[y*32+x] = c(((col>>16)&255)+hi, ((col>>8)&255)+hi, (col&255)+hi, 255);
                }
            }
        }
        writePng("src/main/resources/assets/arsenalmod/textures/item/" + name + ".png", 32, 32, p);
    }
}

TEX_V3_EOF
java TextureGen.java && rm -f TextureGen.java

echo "[5/5] Compilando mod Forge 1.20.1 v3.0..."
"$GBIN" build --no-daemon --console=plain -Dorg.gradle.native=false --stacktrace

JAR_FILE="$(ls build/libs/arsenalmod-*.jar | grep -v sources | head -n 1)"
cp "$JAR_FILE" "$BASE_DIR/arsenalmod-3.0.0-forge-1.20.1.jar"
if [ -d "/sdcard/Download" ] && [ -w "/sdcard/Download" ]; then
    cp "$JAR_FILE" "/sdcard/Download/arsenalmod-3.0.0-forge-1.20.1.jar"
    echo "============================================================"
    echo " SUCESSO! MOD SALVO EM: Download/arsenalmod-3.0.0-forge-1.20.1.jar"
    echo "============================================================"
else
    echo "============================================================"
    echo " SUCESSO! MOD PRONTO EM: $BASE_DIR/arsenalmod-3.0.0-forge-1.20.1.jar"
    echo "============================================================"
fi
