#!/usr/bin/env bash
set -e

echo "=================================================="
echo "   ARSENAL 3D - GERADOR E COMPILADOR AUTOMATICO   "
echo "           Minecraft 1.20.1 Forge                 "
echo "=================================================="

IS_TERMUX=0
if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ]; then
    IS_TERMUX=1
fi

if [ "$IS_TERMUX" -eq 1 ]; then
    echo "[1/5] Preparando Termux (Java 17 + ferramentas)..."
    pkg update -y >/dev/null 2>&1 || true
    pkg install -y openjdk-17 wget unzip >/dev/null
    export JAVA_HOME="${PREFIX}/lib/jvm/java-17-openjdk"
    [ -d "$JAVA_HOME" ] || JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
    export PATH="$JAVA_HOME/bin:$PATH"
    HEAP_MEM="-Xmx1536m"
else
    echo "[1/5] Verificando ambiente Linux/Codespaces/GitHub Actions..."
    if ! command -v java >/dev/null 2>&1; then
        sudo apt-get update -y && sudo apt-get install -y openjdk-17-jdk wget unzip
    fi
    HEAP_MEM="-Xmx3G"
fi

GRADLE_DIR="$HOME/.gradle-8.1.1"
GRADLE_BIN="$GRADLE_DIR/gradle-8.1.1/bin/gradle"
if [ ! -x "$GRADLE_BIN" ]; then
    echo "[2/5] Baixando Gradle 8.1.1 (oficial Forge 1.20.1)..."
    mkdir -p "$GRADLE_DIR"
    wget -q -O "$GRADLE_DIR/gradle.zip" "https://services.gradle.org/distributions/gradle-8.1.1-bin.zip"
    unzip -q -o "$GRADLE_DIR/gradle.zip" -d "$GRADLE_DIR"
    rm -f "$GRADLE_DIR/gradle.zip"
else
    echo "[2/5] Gradle 8.1.1 ja instalado!"
fi

START_DIR="$PWD"
WORKDIR="$START_DIR/arsenalmod_1201"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[3/5] Criando codigo-fonte 3D, animacoes, HUD e modelos..."

mkdir -p src/main/java/com/arsenalmod/{item,registry,entity,network,client}
mkdir -p src/main/resources/META-INF
mkdir -p src/main/resources/assets/arsenalmod/{lang,models/item,textures/item,textures/entity}

cat << 'EOF' > settings.gradle
pluginManagement {
    repositories {
        gradlePluginPortal()
        maven {
            name = 'MinecraftForge'
            url = 'https://maven.minecraftforge.net/'
        }
    }
}
plugins {
    id 'org.gradle.toolchains.foojay-resolver-convention' version '0.7.0'
}
rootProject.name = 'arsenalmod'
EOF

cat << EOF > gradle.properties
org.gradle.jvmargs=${HEAP_MEM}
org.gradle.daemon=false
org.gradle.parallel=false
EOF

cat << 'EOF' > build.gradle
plugins {
    id 'java'
    id 'net.minecraftforge.gradle' version '[6.0,6.2)'
}

group = 'com.arsenalmod'
version = '1.0.0'

base {
    archivesName = 'arsenalmod'
}

java.toolchain.languageVersion = JavaLanguageVersion.of(17)

minecraft {
    mappings channel: 'official', version: '1.20.1'
}

dependencies {
    minecraft 'net.minecraftforge:forge:1.20.1-47.2.0'
}

tasks.withType(JavaCompile).configureEach {
    options.encoding = 'UTF-8'
}

tasks.named('jar', Jar).configure {
    manifest {
        attributes([
            'Specification-Title'    : 'arsenalmod',
            'Specification-Vendor'   : 'arsenalmod',
            'Specification-Version'  : '1',
            'Implementation-Title'   : project.name,
            'Implementation-Version' : project.version,
            'Implementation-Vendor'  : 'arsenalmod'
        ])
    }
    finalizedBy 'reobfJar'
}
EOF

cat << 'EOF' > src/main/resources/pack.mcmeta
{
  "pack": {
    "description": "Arsenal 3D Weapons Resources",
    "pack_format": 15
  }
}
EOF

cat << 'EOF' > src/main/resources/META-INF/mods.toml
modLoader="javafml"
loaderVersion="[47,)"
license="MIT"

[[mods]]
modId="arsenalmod"
version="1.0.0"
displayName="Arsenal 3D - Armas"
description='''Mod de armas 3D detalhadas com animacoes avancadas, mira ADS, sniper com zoom, minigun giratoria e RPG-7 explosiva.'''

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
EOF

cat << 'EOF' > src/main/resources/assets/arsenalmod/lang/pt_br.json
{
  "itemGroup.arsenalmod.arsenal_tab": "Arsenal 3D - Armas",
  "item.arsenalmod.glock19": "Glock 19",
  "item.arsenalmod.ak47": "AK-47",
  "item.arsenalmod.m4a1": "M4A1 Tatica",
  "item.arsenalmod.spas12": "SPAS-12",
  "item.arsenalmod.awp_sniper": "AWP Sniper",
  "item.arsenalmod.minigun": "M134 Minigun",
  "item.arsenalmod.rpg7": "RPG-7",
  "item.arsenalmod.pistol_ammo": "Municao de Pistola",
  "item.arsenalmod.rifle_ammo": "Municao de Fuzil",
  "item.arsenalmod.shotgun_shell": "Cartucho de Espingarda",
  "item.arsenalmod.sniper_ammo": "Municao de Sniper",
  "item.arsenalmod.rocket_ammo": "Foguete PG-7V (RPG)",
  "key.categories.arsenalmod": "Arsenal 3D",
  "key.arsenalmod.reload": "Recarregar Arma"
}
EOF

cp src/main/resources/assets/arsenalmod/lang/pt_br.json src/main/resources/assets/arsenalmod/lang/en_us.json

for gun in glock19 ak47 m4a1 spas12 awp_sniper minigun rpg7; do
cat << 'EOF' > "src/main/resources/assets/arsenalmod/models/item/${gun}.json"
{
  "parent": "builtin/entity",
  "gui_light": "front",
  "display": {
    "firstperson_righthand": { "rotation": [0, 0, 0], "translation": [0, 0, 0], "scale": [1, 1, 1] },
    "firstperson_lefthand":  { "rotation": [0, 0, 0], "translation": [0, 0, 0], "scale": [1, 1, 1] },
    "thirdperson_righthand": { "rotation": [0, 0, 0], "translation": [0, 0, 0], "scale": [1, 1, 1] },
    "thirdperson_lefthand":  { "rotation": [0, 0, 0], "translation": [0, 0, 0], "scale": [1, 1, 1] },
    "gui":    { "rotation": [0, 0, 0], "translation": [0, 0, 0], "scale": [1, 1, 1] },
    "ground": { "rotation": [0, 0, 0], "translation": [0, 0, 0], "scale": [1, 1, 1] },
    "fixed":  { "rotation": [0, 0, 0], "translation": [0, 0, 0], "scale": [1, 1, 1] }
  }
}
EOF
done

for ammo in pistol_ammo rifle_ammo shotgun_shell sniper_ammo rocket_ammo; do
cat << EOF > "src/main/resources/assets/arsenalmod/models/item/${ammo}.json"
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "arsenalmod:item/${ammo}"
  }
}
EOF
done

# ---------------- JAVA: MAIN ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/ArsenalMod.java
package com.arsenalmod;

import com.arsenalmod.network.ModNetwork;
import com.arsenalmod.registry.ModCreativeTabs;
import com.arsenalmod.registry.ModEntities;
import com.arsenalmod.registry.ModItems;
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
        bus.addListener(this::commonSetup);
    }

    private void commonSetup(final FMLCommonSetupEvent event) {
        event.enqueueWork(ModNetwork::register);
    }
}
EOF

# ---------------- JAVA: GUN TYPE ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/item/GunType.java
package com.arsenalmod.item;

public enum GunType {
    GLOCK19("glock19", "Glock 19", 7.5F, 5, 15, 34, false, 1, 1.3F, 5.2F,
            0.09F, 5.5F, 1.3F, 0.85F, false, false, AmmoKind.PISTOL, 15, 2.60F, -4.6F, 1.7F),
    AK47("ak47", "AK-47", 9.0F, 3, 30, 46, true, 1, 2.0F, 5.6F,
            0.13F, 4.4F, 1.1F, 0.78F, false, false, AmmoKind.RIFLE, 15, 2.90F, -15.1F, 0.8F),
    M4A1("m4a1", "M4A1 Tatica", 7.5F, 2, 30, 42, true, 1, 1.1F, 6.0F,
            0.085F, 2.9F, 0.7F, 0.72F, false, false, AmmoKind.RIFLE, 15, 3.50F, -16.0F, 1.0F),
    SPAS12("spas12", "SPAS-12", 4.5F, 16, 8, 52, false, 8, 6.8F, 4.8F,
            0.26F, 11.5F, 3.2F, 0.84F, false, false, AmmoKind.SHOTGUN, 1, 2.70F, -14.0F, 1.4F),
    AWP_SNIPER("awp_sniper", "AWP Sniper", 28.0F, 28, 5, 58, false, 1, 0.12F, 8.5F,
            0.28F, 14.0F, 4.0F, 0.24F, false, true, AmmoKind.SNIPER, 1, 3.70F, -20.8F, 1.3F),
    MINIGUN("minigun", "M134 Minigun", 5.5F, 1, 150, 72, true, 1, 3.4F, 5.6F,
            0.065F, 1.6F, 0.45F, 0.86F, false, false, AmmoKind.RIFLE, 30, 2.60F, -15.4F, 0.4F),
    RPG7("rpg7", "RPG-7", 36.0F, 30, 1, 62, false, 1, 0.35F, 2.5F,
            0.36F, 16.5F, 4.8F, 0.78F, true, false, AmmoKind.ROCKET, 1, 3.40F, -16.8F, 1.2F);

    public enum AmmoKind { PISTOL, RIFLE, SHOTGUN, SNIPER, ROCKET }

    public final String id;
    public final String displayName;
    public final float damage;
    public final int fireCooldown;
    public final int maxAmmo;
    public final int reloadTicks;
    public final boolean fullAuto;
    public final int pellets;
    public final float spread;
    public final float bulletSpeed;
    public final float recoilKick;
    public final float recoilPitch;
    public final float cameraKick;
    public final float adsFov;
    public final boolean isRocket;
    public final boolean isSniper;
    public final AmmoKind ammoKind;
    public final int roundsPerAmmoItem;
    public final float sightVoxelsY;
    public final float muzzleVoxelsZ;
    public final float muzzleVoxelsY;

    GunType(String id, String displayName, float damage, int fireCooldown, int maxAmmo, int reloadTicks,
            boolean fullAuto, int pellets, float spread, float bulletSpeed, float recoilKick,
            float recoilPitch, float cameraKick, float adsFov, boolean isRocket, boolean isSniper,
            AmmoKind ammoKind, int roundsPerAmmoItem, float sightVoxelsY, float muzzleVoxelsZ, float muzzleVoxelsY) {
        this.id = id;
        this.displayName = displayName;
        this.damage = damage;
        this.fireCooldown = fireCooldown;
        this.maxAmmo = maxAmmo;
        this.reloadTicks = reloadTicks;
        this.fullAuto = fullAuto;
        this.pellets = pellets;
        this.spread = spread;
        this.bulletSpeed = bulletSpeed;
        this.recoilKick = recoilKick;
        this.recoilPitch = recoilPitch;
        this.cameraKick = cameraKick;
        this.adsFov = adsFov;
        this.isRocket = isRocket;
        this.isSniper = isSniper;
        this.ammoKind = ammoKind;
        this.roundsPerAmmoItem = roundsPerAmmoItem;
        this.sightVoxelsY = sightVoxelsY;
        this.muzzleVoxelsZ = muzzleVoxelsZ;
        this.muzzleVoxelsY = muzzleVoxelsY;
    }
}
EOF

# ---------------- JAVA: GUN ITEM ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/item/GunItem.java
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
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.HumanoidArm;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraftforge.client.extensions.common.IClientItemExtensions;

import javax.annotation.Nullable;
import java.util.List;
import java.util.function.Consumer;

public class GunItem extends Item {
    public static final String TAG_AMMO = "Ammo";
    public static final String TAG_RELOADING = "Reloading";
    public static final String TAG_RELOAD_START = "ReloadStart";
    public static final String TAG_RELOAD_END = "ReloadEnd";
    public static final String TAG_LAST_SHOT = "LastShot";

    private final GunType type;

    public GunItem(GunType type) {
        super(new Item.Properties().stacksTo(1));
        this.type = type;
    }

    public GunType getType() {
        return type;
    }

    public int getAmmo(ItemStack stack) {
        CompoundTag tag = stack.getTag();
        if (tag == null || !tag.contains(TAG_AMMO)) {
            return type.maxAmmo;
        }
        return tag.getInt(TAG_AMMO);
    }

    public void setAmmo(ItemStack stack, int ammo) {
        stack.getOrCreateTag().putInt(TAG_AMMO, Mth.clamp(ammo, 0, type.maxAmmo));
    }

    public boolean isReloading(ItemStack stack, long gameTime) {
        CompoundTag tag = stack.getTag();
        if (tag == null || !tag.getBoolean(TAG_RELOADING)) return false;
        return gameTime <= tag.getLong(TAG_RELOAD_END) + 2L;
    }

    public float getReloadProgress(ItemStack stack, long gameTime, float partialTick) {
        CompoundTag tag = stack.getTag();
        if (tag == null || !tag.getBoolean(TAG_RELOADING)) return 0.0F;
        long start = tag.getLong(TAG_RELOAD_START);
        long end = tag.getLong(TAG_RELOAD_END);
        if (end <= start) return 0.0F;
        return Mth.clamp(((gameTime + partialTick) - start) / (float) (end - start), 0.0F, 1.0F);
    }

    public long getLastShot(ItemStack stack) {
        CompoundTag tag = stack.getTag();
        return tag == null ? -1000L : tag.getLong(TAG_LAST_SHOT);
    }

    public void setLastShot(ItemStack stack, long tick) {
        stack.getOrCreateTag().putLong(TAG_LAST_SHOT, tick);
    }

    public boolean hasReserveAmmo(Player player) {
        if (player.isCreative()) return true;
        Item ammoItem = ModItems.getAmmoItem(type.ammoKind);
        for (ItemStack invStack : player.getInventory().items) {
            if (invStack.is(ammoItem) && !invStack.isEmpty()) return true;
        }
        return false;
    }

    public void startReload(ItemStack stack, Player player) {
        Level level = player.level();
        long now = level.getGameTime();
        if (isReloading(stack, now)) return;
        if (getAmmo(stack) >= type.maxAmmo) return;
        if (!hasReserveAmmo(player)) {
            level.playSound(null, player.getX(), player.getY(), player.getZ(),
                    SoundEvents.DISPENSER_FAIL, SoundSource.PLAYERS, 0.6F, 1.5F);
            return;
        }
        CompoundTag tag = stack.getOrCreateTag();
        tag.putBoolean(TAG_RELOADING, true);
        tag.putLong(TAG_RELOAD_START, now);
        tag.putLong(TAG_RELOAD_END, now + type.reloadTicks);
        level.playSound(null, player.getX(), player.getY(), player.getZ(),
                SoundEvents.IRON_TRAPDOOR_OPEN, SoundSource.PLAYERS, 0.55F, 1.75F);
    }

    @Override
    public void inventoryTick(ItemStack stack, Level level, Entity entity, int slotId, boolean isSelected) {
        if (level.isClientSide || !(entity instanceof Player player)) return;
        CompoundTag tag = stack.getTag();
        if (tag == null) {
            setAmmo(stack, type.maxAmmo);
            return;
        }
        if (tag.getBoolean(TAG_RELOADING)) {
            if (!isSelected) {
                tag.putBoolean(TAG_RELOADING, false);
                return;
            }
            if (level.getGameTime() >= tag.getLong(TAG_RELOAD_END)) {
                tag.putBoolean(TAG_RELOADING, false);
                int current = getAmmo(stack);
                int needed = type.maxAmmo - current;
                if (player.isCreative()) {
                    setAmmo(stack, type.maxAmmo);
                } else {
                    Item ammoItem = ModItems.getAmmoItem(type.ammoKind);
                    int gained = 0;
                    for (ItemStack inv : player.getInventory().items) {
                        if (gained >= needed) break;
                        if (inv.is(ammoItem) && !inv.isEmpty()) {
                            while (!inv.isEmpty() && gained < needed) {
                                inv.shrink(1);
                                gained += type.roundsPerAmmoItem;
                            }
                        }
                    }
                    setAmmo(stack, Math.min(type.maxAmmo, current + gained));
                }
                level.playSound(null, player.getX(), player.getY(), player.getZ(),
                        SoundEvents.PISTON_CONTRACT, SoundSource.PLAYERS, 0.6F, 1.85F);
            }
        }
    }

    @Override
    public boolean canAttackBlock(BlockState state, Level level, BlockPos pos, Player player) {
        return false;
    }

    @Override
    public boolean shouldCauseReequipAnimation(ItemStack oldStack, ItemStack newStack, boolean slotChanged) {
        return slotChanged || oldStack.getItem() != newStack.getItem();
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        return InteractionResultHolder.pass(player.getItemInHand(hand));
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level level, List<Component> tooltip, TooltipFlag flag) {
        String modo = type.isRocket ? "Explosivo" : (type.fullAuto ? "Automatico" : "Semi-Automatico");
        String danoTxt = type.pellets > 1
                ? String.format("%.1f x%d", type.damage, type.pellets)
                : String.format("%.1f", type.damage);
        tooltip.add(Component.literal("Municao: " + getAmmo(stack) + " / " + type.maxAmmo).withStyle(ChatFormatting.GOLD));
        tooltip.add(Component.literal("Dano: " + danoTxt + " | Modo: " + modo).withStyle(ChatFormatting.GRAY));
        tooltip.add(Component.literal("[Clique Esq] Atirar  [Clique Dir] Mirar  [R] Recarregar").withStyle(ChatFormatting.DARK_AQUA));
    }

    @Override
    public void initializeClient(Consumer<IClientItemExtensions> consumer) {
        consumer.accept(new IClientItemExtensions() {
            private GunItemRenderer renderer;

            @Override
            public BlockEntityWithoutLevelRenderer getCustomRenderer() {
                if (renderer == null) {
                    renderer = new GunItemRenderer();
                }
                return renderer;
            }

            @Override
            public boolean applyForgeHandTransform(PoseStack poseStack, LocalPlayer player, HumanoidArm arm,
                    ItemStack itemInHand, float partialTick, float equipProcess, float swingProcess) {
                return GunAnimationEngine.applyFirstPersonTransform(poseStack, player, arm, itemInHand, partialTick, equipProcess);
            }

            @Override
            public HumanoidModel.ArmPose getArmPose(LivingEntity entityLiving, InteractionHand hand, ItemStack itemStack) {
                return HumanoidModel.ArmPose.BOW_AND_ARROW;
            }
        });
    }
}
EOF

# ---------------- JAVA: REGISTRIES ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/registry/ModItems.java
package com.arsenalmod.registry;

import com.arsenalmod.ArsenalMod;
import com.arsenalmod.item.GunItem;
import com.arsenalmod.item.GunType;
import net.minecraft.world.item.Item;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public class ModItems {
    public static final DeferredRegister<Item> ITEMS =
            DeferredRegister.create(ForgeRegistries.ITEMS, ArsenalMod.MODID);

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

    public static Item getAmmoItem(GunType.AmmoKind kind) {
        return switch (kind) {
            case PISTOL -> PISTOL_AMMO.get();
            case RIFLE -> RIFLE_AMMO.get();
            case SHOTGUN -> SHOTGUN_SHELL.get();
            case SNIPER -> SNIPER_AMMO.get();
            case ROCKET -> ROCKET_AMMO.get();
        };
    }
}
EOF

cat << 'EOF' > src/main/java/com/arsenalmod/registry/ModEntities.java
package com.arsenalmod.registry;

import com.arsenalmod.ArsenalMod;
import com.arsenalmod.entity.BulletEntity;
import com.arsenalmod.entity.RocketEntity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public class ModEntities {
    public static final DeferredRegister<EntityType<?>> ENTITIES =
            DeferredRegister.create(ForgeRegistries.ENTITY_TYPES, ArsenalMod.MODID);

    public static final RegistryObject<EntityType<BulletEntity>> BULLET = ENTITIES.register("bullet",
            () -> EntityType.Builder.<BulletEntity>of(BulletEntity::new, MobCategory.MISC)
                    .sized(0.15F, 0.15F)
                    .clientTrackingRange(8)
                    .updateInterval(1)
                    .build("bullet"));

    public static final RegistryObject<EntityType<RocketEntity>> ROCKET = ENTITIES.register("rocket",
            () -> EntityType.Builder.<RocketEntity>of(RocketEntity::new, MobCategory.MISC)
                    .sized(0.4F, 0.4F)
                    .clientTrackingRange(10)
                    .updateInterval(1)
                    .build("rocket"));
}
EOF

cat << 'EOF' > src/main/java/com/arsenalmod/registry/ModCreativeTabs.java
package com.arsenalmod.registry;

import com.arsenalmod.ArsenalMod;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.RegistryObject;

public class ModCreativeTabs {
    public static final DeferredRegister<CreativeModeTab> TABS =
            DeferredRegister.create(Registries.CREATIVE_MODE_TAB, ArsenalMod.MODID);

    public static final RegistryObject<CreativeModeTab> ARSENAL_TAB = TABS.register("arsenal_tab",
            () -> CreativeModeTab.builder()
                    .title(Component.translatable("itemGroup.arsenalmod.arsenal_tab"))
                    .icon(() -> new ItemStack(ModItems.AK47.get()))
                    .displayItems((params, output) -> {
                        output.accept(ModItems.GLOCK19.get());
                        output.accept(ModItems.AK47.get());
                        output.accept(ModItems.M4A1.get());
                        output.accept(ModItems.SPAS12.get());
                        output.accept(ModItems.AWP_SNIPER.get());
                        output.accept(ModItems.MINIGUN.get());
                        output.accept(ModItems.RPG7.get());
                        output.accept(ModItems.PISTOL_AMMO.get());
                        output.accept(ModItems.RIFLE_AMMO.get());
                        output.accept(ModItems.SHOTGUN_SHELL.get());
                        output.accept(ModItems.SNIPER_AMMO.get());
                        output.accept(ModItems.ROCKET_AMMO.get());
                    })
                    .build());
}
EOF

# ---------------- JAVA: ENTITIES ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/entity/BulletEntity.java
package com.arsenalmod.entity;

import com.arsenalmod.registry.ModEntities;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.projectile.ThrowableProjectile;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.EntityHitResult;
import net.minecraft.world.phys.Vec3;

public class BulletEntity extends ThrowableProjectile {
    private float damage = 8.0F;

    public BulletEntity(EntityType<? extends BulletEntity> type, Level level) {
        super(type, level);
    }

    public BulletEntity(Level level, LivingEntity shooter, float damage) {
        super(ModEntities.BULLET.get(), shooter, level);
        this.damage = damage;
    }

    @Override
    protected void defineSynchedData() {
    }

    @Override
    protected float getGravity() {
        return 0.004F;
    }

    @Override
    public void tick() {
        super.tick();
        if (this.level().isClientSide && this.tickCount % 2 == 0) {
            this.level().addParticle(ParticleTypes.SMOKE, this.getX(), this.getY(), this.getZ(), 0, 0, 0);
        }
        if (this.tickCount > 60) {
            this.discard();
        }
    }

    @Override
    protected void onHitEntity(EntityHitResult result) {
        super.onHitEntity(result);
        Entity target = result.getEntity();
        Entity owner = this.getOwner();
        if (target == owner) return;
        if (!this.level().isClientSide) {
            boolean headshot = result.getLocation().y >= target.getY() + target.getBbHeight() * 0.72D;
            float dmg = headshot ? this.damage * 1.75F : this.damage;
            target.invulnerableTime = 0;
            DamageSource src = this.damageSources().thrown(this, owner);
            target.hurt(src, dmg);
            if (headshot && owner instanceof ServerPlayer sp) {
                sp.playNotifySound(SoundEvents.EXPERIENCE_ORB_PICKUP, SoundSource.PLAYERS, 0.7F, 1.9F);
            }
            if (this.level() instanceof ServerLevel sl) {
                Vec3 hit = result.getLocation();
                sl.sendParticles(headshot ? ParticleTypes.CRIT : ParticleTypes.DAMAGE_INDICATOR,
                        hit.x, hit.y, hit.z, headshot ? 8 : 3, 0.1, 0.1, 0.1, 0.15);
            }
            this.discard();
        }
    }

    @Override
    protected void onHitBlock(BlockHitResult result) {
        super.onHitBlock(result);
        if (!this.level().isClientSide) {
            Vec3 hit = result.getLocation();
            if (this.level() instanceof ServerLevel sl) {
                sl.sendParticles(ParticleTypes.POOF, hit.x, hit.y, hit.z, 3, 0.05, 0.05, 0.05, 0.04);
                sl.sendParticles(ParticleTypes.CRIT, hit.x, hit.y, hit.z, 4, 0.05, 0.05, 0.05, 0.12);
            }
            this.level().playSound(null, hit.x, hit.y, hit.z,
                    SoundEvents.STONE_HIT, SoundSource.BLOCKS, 0.45F, 1.8F);
            this.discard();
        }
    }
}
EOF

cat << 'EOF' > src/main/java/com/arsenalmod/entity/RocketEntity.java
package com.arsenalmod.entity;

import com.arsenalmod.registry.ModEntities;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.projectile.ThrowableProjectile;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.EntityHitResult;
import net.minecraft.world.phys.Vec3;

public class RocketEntity extends ThrowableProjectile {
    private float directDamage = 36.0F;

    public RocketEntity(EntityType<? extends RocketEntity> type, Level level) {
        super(type, level);
    }

    public RocketEntity(Level level, LivingEntity shooter, float directDamage) {
        super(ModEntities.ROCKET.get(), shooter, level);
        this.directDamage = directDamage;
    }

    @Override
    protected void defineSynchedData() {
    }

    @Override
    protected float getGravity() {
        return 0.009F;
    }

    @Override
    public void tick() {
        super.tick();
        if (this.level().isClientSide) {
            Vec3 m = this.getDeltaMovement();
            for (int i = 0; i < 3; i++) {
                double f = i * 0.3;
                this.level().addParticle(ParticleTypes.FLAME,
                        this.getX() - m.x * f, this.getY() - m.y * f, this.getZ() - m.z * f,
                        (this.random.nextDouble() - 0.5) * 0.05,
                        (this.random.nextDouble() - 0.5) * 0.05,
                        (this.random.nextDouble() - 0.5) * 0.05);
            }
            this.level().addParticle(ParticleTypes.CAMPFIRE_COSY_SMOKE,
                    this.getX() - m.x * 0.5, this.getY() - m.y * 0.5, this.getZ() - m.z * 0.5,
                    0, 0.02, 0);
        }
        if (this.tickCount > 110) {
            explode();
        }
    }

    private void explode() {
        if (!this.level().isClientSide) {
            if (this.level() instanceof ServerLevel sl) {
                sl.sendParticles(ParticleTypes.EXPLOSION_EMITTER, this.getX(), this.getY(), this.getZ(), 2, 0.3, 0.3, 0.3, 0.0);
                sl.sendParticles(ParticleTypes.FLAME, this.getX(), this.getY(), this.getZ(), 35, 0.8, 0.8, 0.8, 0.25);
            }
            this.level().explode(this, this.getX(), this.getY(), this.getZ(), 4.5F, Level.ExplosionInteraction.TNT);
            this.discard();
        }
    }

    @Override
    protected void onHitEntity(EntityHitResult result) {
        super.onHitEntity(result);
        Entity target = result.getEntity();
        if (target == this.getOwner()) return;
        if (!this.level().isClientSide) {
            target.hurt(this.damageSources().thrown(this, this.getOwner()), this.directDamage);
            explode();
        }
    }

    @Override
    protected void onHitBlock(BlockHitResult result) {
        super.onHitBlock(result);
        explode();
    }
}
EOF

# ---------------- JAVA: NETWORK ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/network/ModNetwork.java
package com.arsenalmod.network;

import com.arsenalmod.ArsenalMod;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.network.NetworkDirection;
import net.minecraftforge.network.NetworkRegistry;
import net.minecraftforge.network.simple.SimpleChannel;

public class ModNetwork {
    private static final String PROTOCOL = "1";
    public static final SimpleChannel INSTANCE = NetworkRegistry.newSimpleChannel(
            new ResourceLocation(ArsenalMod.MODID, "main"),
            () -> PROTOCOL,
            PROTOCOL::equals,
            PROTOCOL::equals
    );

    public static void register() {
        int id = 0;
        INSTANCE.messageBuilder(C2SShootPacket.class, id++, NetworkDirection.PLAY_TO_SERVER)
                .encoder(C2SShootPacket::encode)
                .decoder(C2SShootPacket::decode)
                .consumerMainThread(C2SShootPacket::handle)
                .add();
        INSTANCE.messageBuilder(C2SReloadPacket.class, id++, NetworkDirection.PLAY_TO_SERVER)
                .encoder(C2SReloadPacket::encode)
                .decoder(C2SReloadPacket::decode)
                .consumerMainThread(C2SReloadPacket::handle)
                .add();
    }
}
EOF

cat << 'EOF' > src/main/java/com/arsenalmod/network/C2SShootPacket.java
package com.arsenalmod.network;

import com.arsenalmod.entity.BulletEntity;
import com.arsenalmod.entity.RocketEntity;
import com.arsenalmod.item.GunItem;
import com.arsenalmod.item.GunType;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.network.NetworkEvent;

import java.util.function.Supplier;

public class C2SShootPacket {
    private final boolean aiming;

    public C2SShootPacket(boolean aiming) {
        this.aiming = aiming;
    }

    public static void encode(C2SShootPacket msg, FriendlyByteBuf buf) {
        buf.writeBoolean(msg.aiming);
    }

    public static C2SShootPacket decode(FriendlyByteBuf buf) {
        return new C2SShootPacket(buf.readBoolean());
    }

    public static void handle(C2SShootPacket msg, Supplier<NetworkEvent.Context> ctx) {
        ServerPlayer player = ctx.get().getSender();
        if (player == null) return;

        ItemStack stack = player.getMainHandItem();
        if (!(stack.getItem() instanceof GunItem gun)) return;

        ServerLevel level = player.serverLevel();
        long now = level.getGameTime();
        GunType type = gun.getType();

        if (gun.isReloading(stack, now)) return;
        if (now - gun.getLastShot(stack) < type.fireCooldown) return;

        int ammo = gun.getAmmo(stack);
        if (ammo <= 0) {
            gun.startReload(stack, player);
            return;
        }

        gun.setAmmo(stack, ammo - 1);
        gun.setLastShot(stack, now);

        Vec3 eye = player.getEyePosition();
        Vec3 look = player.getLookAngle();
        float spread = msg.aiming ? type.spread * 0.25F : type.spread;

        if (type.isRocket) {
            RocketEntity rocket = new RocketEntity(level, player, type.damage);
            Vec3 spawnPos = eye.add(look.scale(0.85));
            rocket.setPos(spawnPos.x, spawnPos.y - 0.08, spawnPos.z);
            rocket.shoot(look.x, look.y, look.z, type.bulletSpeed, spread);
            level.addFreshEntity(rocket);
        } else {
            for (int i = 0; i < type.pellets; i++) {
                BulletEntity bullet = new BulletEntity(level, player, type.damage);
                Vec3 spawnPos = eye.add(look.scale(0.55));
                bullet.setPos(spawnPos.x, spawnPos.y - 0.05, spawnPos.z);
                bullet.shoot(look.x, look.y, look.z, type.bulletSpeed, spread);
                level.addFreshEntity(bullet);
            }
        }

        playWeaponSound(level, player, type);

        Vec3 muzzle = eye.add(look.scale(1.15));
        level.sendParticles(ParticleTypes.SMOKE, muzzle.x, muzzle.y - 0.1, muzzle.z,
                type.isRocket ? 14 : 4, 0.08, 0.08, 0.08, 0.04);
        level.sendParticles(ParticleTypes.FLAME, muzzle.x, muzzle.y - 0.1, muzzle.z,
                type.isRocket ? 8 : 2, 0.05, 0.05, 0.05, 0.03);
    }

    private static void playWeaponSound(ServerLevel level, ServerPlayer p, GunType type) {
        double x = p.getX(), y = p.getY(), z = p.getZ();
        switch (type) {
            case GLOCK19 -> {
                level.playSound(null, x, y, z, SoundEvents.FIREWORK_ROCKET_BLAST, SoundSource.PLAYERS, 1.0F, 1.85F);
                level.playSound(null, x, y, z, SoundEvents.GENERIC_EXPLODE, SoundSource.PLAYERS, 0.22F, 2.0F);
            }
            case AK47 -> {
                level.playSound(null, x, y, z, SoundEvents.GENERIC_EXPLODE, SoundSource.PLAYERS, 0.55F, 1.35F);
                level.playSound(null, x, y, z, SoundEvents.FIREWORK_ROCKET_BLAST, SoundSource.PLAYERS, 1.1F, 1.15F);
            }
            case M4A1 -> {
                level.playSound(null, x, y, z, SoundEvents.FIREWORK_ROCKET_BLAST, SoundSource.PLAYERS, 0.75F, 1.68F);
                level.playSound(null, x, y, z, SoundEvents.IRON_TRAPDOOR_CLOSE, SoundSource.PLAYERS, 0.55F, 1.9F);
            }
            case SPAS12 -> {
                level.playSound(null, x, y, z, SoundEvents.GENERIC_EXPLODE, SoundSource.PLAYERS, 0.95F, 0.88F);
                level.playSound(null, x, y, z, SoundEvents.FIREWORK_ROCKET_LARGE_BLAST, SoundSource.PLAYERS, 1.1F, 0.85F);
            }
            case AWP_SNIPER -> {
                level.playSound(null, x, y, z, SoundEvents.GENERIC_EXPLODE, SoundSource.PLAYERS, 1.25F, 0.72F);
                level.playSound(null, x, y, z, SoundEvents.LIGHTNING_BOLT_THUNDER, SoundSource.PLAYERS, 0.35F, 2.0F);
            }
            case MINIGUN -> {
                level.playSound(null, x, y, z, SoundEvents.FIREWORK_ROCKET_BLAST, SoundSource.PLAYERS, 0.72F, 1.32F);
                level.playSound(null, x, y, z, SoundEvents.PISTON_EXTEND, SoundSource.PLAYERS, 0.35F, 2.0F);
            }
            case RPG7 -> {
                level.playSound(null, x, y, z, SoundEvents.FIREWORK_ROCKET_LAUNCH, SoundSource.PLAYERS, 1.6F, 0.62F);
                level.playSound(null, x, y, z, SoundEvents.GENERIC_EXPLODE, SoundSource.PLAYERS, 0.85F, 0.68F);
            }
        }
    }
}
EOF

cat << 'EOF' > src/main/java/com/arsenalmod/network/C2SReloadPacket.java
package com.arsenalmod.network;

import com.arsenalmod.item.GunItem;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.network.NetworkEvent;

import java.util.function.Supplier;

public class C2SReloadPacket {
    public C2SReloadPacket() {}

    public static void encode(C2SReloadPacket msg, FriendlyByteBuf buf) {}

    public static C2SReloadPacket decode(FriendlyByteBuf buf) {
        return new C2SReloadPacket();
    }

    public static void handle(C2SReloadPacket msg, Supplier<NetworkEvent.Context> ctx) {
        ServerPlayer player = ctx.get().getSender();
        if (player == null) return;
        ItemStack stack = player.getMainHandItem();
        if (stack.getItem() instanceof GunItem gun) {
            gun.startReload(stack, player);
        }
    }
}
EOF

# ---------------- JAVA: CLIENT ANIMATION ENGINE ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/client/GunAnimationEngine.java
package com.arsenalmod.client;

import com.arsenalmod.item.GunItem;
import com.arsenalmod.item.GunType;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.HumanoidArm;
import net.minecraft.world.item.ItemStack;

public class GunAnimationEngine {
    public static boolean isAiming = false;
    public static float adsProgress = 0.0F;
    public static float sprintProgress = 0.0F;

    public static float recoilZ = 0.0F;
    public static float recoilPitch = 0.0F;
    public static float recoilRoll = 0.0F;
    public static float slideOffset = 0.0F;
    public static float muzzleFlash = 0.0F;
    public static float muzzleAngle = 0.0F;

    public static float pumpTimer = 0.0F;
    public static float boltTimer = 0.0F;
    public static float minigunAngle = 0.0F;
    public static float minigunSpeed = 0.0F;

    public static float reloadMagOffsetY = 0.0F;
    public static boolean reloadMagVisible = true;
    public static float reloadBoltPull = 0.0F;
    public static float reloadWarheadSlide = 0.0F;

    private static long lastNano = System.nanoTime();
    private static int lastReloadStage = 0;

    public static void onLocalShot(GunType type, LocalPlayer player) {
        float aimMul = isAiming ? 0.52F : 1.0F;
        recoilZ = Math.min(0.45F, recoilZ + type.recoilKick * aimMul);
        recoilPitch = Math.min(26.0F, recoilPitch + type.recoilPitch * aimMul);
        recoilRoll = (float) ((Math.random() - 0.5) * 6.5F * aimMul);
        slideOffset = 1.0F;
        muzzleFlash = 1.0F;
        muzzleAngle = (float) (Math.random() * 360.0);

        if (type == GunType.SPAS12) {
            pumpTimer = 0.55F;
        } else if (type == GunType.AWP_SNIPER) {
            boltTimer = 0.85F;
        } else if (type == GunType.MINIGUN) {
            minigunSpeed = Math.min(1100.0F, minigunSpeed + 380.0F);
        }

        if (player != null) {
            float camKick = type.cameraKick * (isAiming ? 0.55F : 1.0F);
            player.setXRot(Mth.clamp(player.getXRot() - camKick, -89.5F, 89.5F));
            player.setYRot(player.getYRot() + (float) ((Math.random() - 0.5) * camKick * 0.55F));
        }
    }

    public static void updateFrame() {
        long now = System.nanoTime();
        float dt = Math.min(0.05F, (now - lastNano) / 1_000_000_000.0F);
        lastNano = now;

        Minecraft mc = Minecraft.getInstance();
        LocalPlayer player = mc.player;
        boolean holdingGun = player != null && player.getMainHandItem().getItem() instanceof GunItem;
        boolean reloading = false;
        if (holdingGun) {
            ItemStack st = player.getMainHandItem();
            reloading = ((GunItem) st.getItem()).isReloading(st, player.level().getGameTime());
        } else {
            isAiming = false;
        }

        float targetAds = (holdingGun && isAiming && !reloading) ? 1.0F : 0.0F;
        adsProgress += (targetAds - adsProgress) * Math.min(1.0F, dt * 14.0F);

        boolean sprinting = holdingGun && player.isSprinting() && !isAiming && !reloading && recoilZ < 0.03F;
        float targetSprint = sprinting ? 1.0F : 0.0F;
        sprintProgress += (targetSprint - sprintProgress) * Math.min(1.0F, dt * 10.0F);

        recoilZ *= (float) Math.exp(-dt * 15.0F);
        recoilPitch *= (float) Math.exp(-dt * 12.0F);
        recoilRoll *= (float) Math.exp(-dt * 11.0F);
        slideOffset *= (float) Math.exp(-dt * 20.0F);
        muzzleFlash = Math.max(0.0F, muzzleFlash - dt * 15.0F);

        if (pumpTimer > 0.0F) {
            float prev = pumpTimer;
            pumpTimer = Math.max(0.0F, pumpTimer - dt);
            if (prev > 0.36F && pumpTimer <= 0.36F && player != null) {
                player.playSound(SoundEvents.PISTON_EXTEND, 0.45F, 1.65F);
            }
            if (prev > 0.14F && pumpTimer <= 0.14F && player != null) {
                player.playSound(SoundEvents.PISTON_CONTRACT, 0.45F, 1.85F);
            }
        }
        if (boltTimer > 0.0F) {
            float prev = boltTimer;
            boltTimer = Math.max(0.0F, boltTimer - dt);
            if (prev > 0.55F && boltTimer <= 0.55F && player != null) {
                player.playSound(SoundEvents.IRON_TRAPDOOR_OPEN, 0.45F, 1.9F);
            }
            if (prev > 0.22F && boltTimer <= 0.22F && player != null) {
                player.playSound(SoundEvents.IRON_TRAPDOOR_CLOSE, 0.45F, 1.8F);
            }
        }

        minigunAngle = (minigunAngle + minigunSpeed * dt) % 360.0F;
        minigunSpeed *= (float) Math.exp(-dt * 3.2F);
    }

    public static float getPumpOffset() {
        if (pumpTimer <= 0.0F || pumpTimer > 0.44F) return 0.0F;
        float p = 1.0F - (pumpTimer / 0.44F);
        return Mth.sin(p * (float) Math.PI);
    }

    public static float getBoltCycle() {
        if (boltTimer <= 0.0F || boltTimer > 0.72F) return 0.0F;
        float p = 1.0F - (boltTimer / 0.72F);
        return Mth.sin(p * (float) Math.PI);
    }

    public static boolean applyFirstPersonTransform(PoseStack ps, LocalPlayer player, HumanoidArm arm,
            ItemStack stack, float partialTick, float equipProcess) {
        if (!(stack.getItem() instanceof GunItem gun)) return false;
        GunType type = gun.getType();
        int side = (arm == HumanoidArm.RIGHT) ? 1 : -1;

        long gameTime = player.level().getGameTime();
        boolean reloading = gun.isReloading(stack, gameTime);
        float rel = reloading ? gun.getReloadProgress(stack, gameTime, partialTick) : 0.0F;

        // Hip-fire -> ADS smooth interpolation
        float hipX = (type == GunType.MINIGUN ? 0.34F : 0.33F) * side;
        float hipY = (type == GunType.MINIGUN ? -0.44F : -0.30F);
        float hipZ = (type == GunType.GLOCK19 ? -0.58F : -0.66F);

        float adsX = (type == GunType.MINIGUN ? 0.14F * side : 0.0F);
        float adsY = -(type.sightVoxelsY / 16.0F);
        float adsZ = (type == GunType.GLOCK19 ? -0.44F : (type == GunType.AWP_SNIPER ? -0.36F : -0.46F));

        float x = Mth.lerp(adsProgress, hipX, adsX);
        float y = Mth.lerp(adsProgress, hipY, adsY);
        float z = Mth.lerp(adsProgress, hipZ, adsZ);

        // Idle breathing sway + walking bob
        float time = (gameTime + partialTick) * 0.08F;
        float swayScale = 1.0F - adsProgress * 0.82F;
        float walkDist = Mth.lerp(partialTick, player.walkDistO, player.walkDist);
        float walkSpeed = Mth.lerp(partialTick, player.oBob, player.bob);

        x += (Mth.cos(time * 0.85F) * 0.004F + Mth.cos(walkDist * (float) Math.PI) * walkSpeed * 0.16F) * swayScale;
        y += (Mth.sin(time * 1.7F) * 0.004F - Math.abs(Mth.sin(walkDist * (float) Math.PI)) * walkSpeed * 0.18F) * swayScale;

        // Equip swing-up
        y -= equipProcess * 0.55F;

        // Recoil kickback
        z += recoilZ;
        y += recoilZ * 0.12F;

        // Reload multi-phase animation
        float relRotX = 0.0F, relRotY = 0.0F, relRotZ = 0.0F;
        reloadMagOffsetY = 0.0F;
        reloadMagVisible = true;
        reloadBoltPull = 0.0F;
        reloadWarheadSlide = 0.0F;

        if (reloading) {
            int stage = rel < 0.22F ? 1 : (rel < 0.65F ? 2 : (rel < 0.82F ? 3 : 4));
            if (stage != lastReloadStage) {
                if (stage == 3) player.playSound(SoundEvents.IRON_TRAPDOOR_CLOSE, 0.55F, 1.7F);
                if (stage == 4) player.playSound(SoundEvents.PISTON_EXTEND, 0.45F, 1.9F);
                lastReloadStage = stage;
            }

            float tiltEnv = rel < 0.15F ? rel / 0.15F : (rel > 0.88F ? (1.0F - rel) / 0.12F : 1.0F);
            relRotZ = 28.0F * tiltEnv * side;
            relRotX = 14.0F * tiltEnv;
            relRotY = 12.0F * tiltEnv * side;
            y -= 0.06F * tiltEnv;

            if (type == GunType.RPG7) {
                if (rel < 0.30F) {
                    reloadWarheadSlide = 1.0F;
                } else if (rel < 0.78F) {
                    float t = (rel - 0.30F) / 0.48F;
                    reloadWarheadSlide = 1.0F - t;
                } else {
                    reloadWarheadSlide = 0.0F;
                    float bump = Mth.sin(((rel - 0.78F) / 0.22F) * (float) Math.PI);
                    z += bump * 0.06F;
                }
            } else {
                if (rel >= 0.16F && rel < 0.42F) {
                    float t = (rel - 0.16F) / 0.26F;
                    reloadMagOffsetY = -t * 7.5F;
                } else if (rel >= 0.42F && rel < 0.50F) {
                    reloadMagVisible = false;
                    reloadMagOffsetY = -8.0F;
                } else if (rel >= 0.50F && rel < 0.74F) {
                    float t = (rel - 0.50F) / 0.24F;
                    reloadMagOffsetY = -(1.0F - t) * 7.5F;
                } else if (rel >= 0.74F && rel < 0.88F) {
                    float t = (rel - 0.74F) / 0.14F;
                    float bump = Mth.sin(t * (float) Math.PI);
                    y += bump * 0.035F;
                    reloadBoltPull = bump;
                }
            }
        } else {
            lastReloadStage = 0;
        }

        // Sprint tactical pose
        float spX = -0.10F * side * sprintProgress;
        float spY = -0.07F * sprintProgress;
        float spRotY = 34.0F * side * sprintProgress;
        float spRotX = -14.0F * sprintProgress;

        // Pump & bolt tactile body tilt
        float pump = getPumpOffset();
        float bolt = getBoltCycle();

        ps.translate(x + spX, y + spY, z);
        ps.mulPose(Axis.YP.rotationDegrees(spRotY + relRotY));
        ps.mulPose(Axis.XP.rotationDegrees(recoilPitch + spRotX + relRotX - equipProcess * 35.0F + pump * 6.0F));
        ps.mulPose(Axis.ZP.rotationDegrees(recoilRoll + relRotZ + bolt * 18.0F * side));

        return true;
    }
}
EOF

# ---------------- JAVA: 3D MODEL GEOMETRY ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/client/GunModelGeometry.java
package com.arsenalmod.client;

import com.arsenalmod.ArsenalMod;
import com.arsenalmod.item.GunType;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import net.minecraft.client.renderer.LightTexture;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import org.joml.Matrix3f;
import org.joml.Matrix4f;

public class GunModelGeometry {
    public static final ResourceLocation ATLAS = new ResourceLocation(ArsenalMod.MODID, "textures/entity/weapons_atlas.png");

    // Material tile indices (col, row) in 8x8 atlas (each tile 32x32)
    static final int T_GUNMETAL_DARK = 0;
    static final int T_GUNMETAL_MID  = 1;
    static final int T_STEEL_CHROME  = 2;
    static final int T_POLYMER       = 3;
    static final int T_GRIP          = 4;
    static final int T_PICATINNY     = 5;
    static final int T_WOOD_AK       = 6;
    static final int T_WOOD_DARK     = 7;
    static final int T_OLIVE         = 8;
    static final int T_TAN           = 9;
    static final int T_BRASS         = 10;
    static final int T_SCOPE_LENS    = 11;
    static final int T_GLOW_RED      = 12;
    static final int T_GLOW_GREEN    = 13;
    static final int T_MUZZLE_FLASH  = 14;
    static final int T_VENT_BARREL   = 15;

    private static final float S = 1.0F / 16.0F;

    public static void renderGun(GunType type, PoseStack ps, MultiBufferSource buffer, int light, int overlay,
                                 boolean firstPerson, int ammo, boolean reloading) {
        VertexConsumer vc = buffer.getBuffer(RenderType.entityCutoutNoCull(ATLAS));
        float slide = firstPerson ? Math.max(GunAnimationEngine.slideOffset, GunAnimationEngine.reloadBoltPull) : 0.0F;
        float magY = firstPerson ? GunAnimationEngine.reloadMagOffsetY : 0.0F;
        boolean magVis = !firstPerson || GunAnimationEngine.reloadMagVisible;
        float pump = firstPerson ? GunAnimationEngine.getPumpOffset() : 0.0F;
        float bolt = firstPerson ? Math.max(GunAnimationEngine.getBoltCycle(), GunAnimationEngine.reloadBoltPull) : 0.0F;
        float spin = firstPerson ? GunAnimationEngine.minigunAngle : 0.0F;

        switch (type) {
            case GLOCK19 -> renderGlock19(ps, vc, light, overlay, slide, magY, magVis, ammo == 0 && !reloading);
            case AK47 -> renderAK47(ps, vc, light, overlay, slide, magY, magVis);
            case M4A1 -> renderM4A1(ps, vc, light, overlay, slide, magY, magVis);
            case SPAS12 -> renderSPAS12(ps, vc, light, overlay, pump, slide);
            case AWP_SNIPER -> renderAWP(ps, vc, light, overlay, bolt, magY, magVis);
            case MINIGUN -> renderMinigun(ps, vc, light, overlay, spin);
            case RPG7 -> {
                boolean showWarhead = ammo > 0 || (firstPerson && reloading && GunAnimationEngine.reloadWarheadSlide < 0.99F);
                float whSlide = (firstPerson && reloading) ? GunAnimationEngine.reloadWarheadSlide : 0.0F;
                renderRPG7(ps, vc, light, overlay, showWarhead, whSlide);
            }
        }

        if (firstPerson && GunAnimationEngine.muzzleFlash > 0.05F) {
            renderMuzzleFlash(ps, vc, type.muzzleVoxelsY, type.muzzleVoxelsZ,
                    type == GunType.SPAS12 || type == GunType.RPG7 ? 2.8F : 1.9F,
                    GunAnimationEngine.muzzleFlash, GunAnimationEngine.muzzleAngle);
        }
    }

    private static void renderGlock19(PoseStack ps, VertexConsumer vc, int light, int ov,
                                      float slide, float magY, boolean magVis, boolean lockBack) {
        box(ps, vc, light, ov, T_POLYMER, 0, 0.55F, -0.5F, 1.55F, 1.05F, 6.8F);
        box(ps, vc, light, ov, T_PICATINNY, 0, -0.05F, -2.5F, 1.15F, 0.35F, 2.5F);
        box(ps, vc, light, ov, T_POLYMER, 0, 0.7F, 3.0F, 1.35F, 0.7F, 0.9F);
        box(ps, vc, light, ov, T_POLYMER, 0, -0.85F, -0.55F, 0.65F, 0.28F, 2.3F);
        box(ps, vc, light, ov, T_POLYMER, 0, -0.35F, -1.6F, 0.65F, 1.1F, 0.3F);
        rotBox(ps, vc, light, ov, T_STEEL_CHROME, 0, -0.2F, -0.1F, 0.28F, 0.85F, 0.25F, -18 - slide * 18, 0, 0);
        rotBox(ps, vc, light, ov, T_GRIP, 0, -1.75F, 1.85F, 1.48F, 4.1F, 2.05F, 16, 0, 0);
        box(ps, vc, light, ov, T_STEEL_CHROME, 0, 1.65F, -1.5F, 0.85F, 0.85F, 5.8F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 1.65F, -4.45F, 0.65F, 0.65F, 0.25F);

        if (magVis) {
            ps.pushPose();
            ps.translate(0, magY * S, -magY * 0.28F * S);
            rotBox(ps, vc, light, ov, T_GUNMETAL_MID, 0, -2.05F, 1.9F, 1.12F, 4.0F, 1.5F, 16, 0, 0);
            rotBox(ps, vc, light, ov, T_POLYMER, 0, -3.95F, 2.45F, 1.52F, 0.55F, 2.05F, 16, 0, 0);
            rotBox(ps, vc, light, ov, T_BRASS, 0, -0.15F, 1.35F, 0.6F, 0.45F, 1.0F, 16, 0, 0);
            ps.popPose();
        }

        float slideZ = (lockBack ? 1.5F : slide * 2.1F);
        ps.pushPose();
        ps.translate(0, 0, slideZ * S);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 1.7F, -0.65F, 1.66F, 1.32F, 6.9F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 2.38F, -0.65F, 1.32F, 0.22F, 6.7F);
        for (int i = 0; i < 4; i++) {
            box(ps, vc, light, ov, T_POLYMER, 0, 1.7F, 1.3F + i * 0.42F, 1.72F, 0.95F, 0.16F);
        }
        box(ps, vc, light, ov, T_GUNMETAL_DARK, -0.42F, 2.62F, 2.35F, 0.35F, 0.36F, 0.45F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK,  0.42F, 2.62F, 2.35F, 0.35F, 0.36F, 0.45F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_GREEN, -0.42F, 2.66F, 2.58F, 0.16F, 0.16F, 0.08F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_GREEN,  0.42F, 2.66F, 2.58F, 0.16F, 0.16F, 0.08F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 2.62F, -3.75F, 0.25F, 0.38F, 0.45F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_RED, 0, 2.66F, -3.52F, 0.16F, 0.18F, 0.08F);
        ps.popPose();
    }

    private static void renderAK47(PoseStack ps, VertexConsumer vc, int light, int ov,
                                   float slide, float magY, boolean magVis) {
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 0.75F, -0.4F, 1.85F, 1.95F, 7.2F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.92F, 0.15F, 1.55F, 0.72F, 5.9F);
        rotBox(ps, vc, light, ov, T_WOOD_AK, 0, 0.05F, 6.15F, 1.55F, 2.15F, 6.4F, -10, 0, 0);
        rotBox(ps, vc, light, ov, T_WOOD_AK, 0, -0.55F, 7.75F, 1.52F, 1.65F, 3.2F, -12, 0, 0);
        rotBox(ps, vc, light, ov, T_GUNMETAL_DARK, 0, -0.25F, 9.35F, 1.58F, 2.75F, 0.38F, -8, 0, 0);
        rotBox(ps, vc, light, ov, T_WOOD_DARK, 0, -1.75F, 2.15F, 1.28F, 3.7F, 1.55F, 18, 0, 0);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, -0.75F, 0.25F, 0.55F, 0.22F, 2.2F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, -0.25F, -0.8F, 0.55F, 1.0F, 0.25F);
        box(ps, vc, light, ov, T_WOOD_AK, 0, 0.55F, -6.3F, 1.88F, 1.48F, 4.9F);
        box(ps, vc, light, ov, T_WOOD_AK, 0, 1.65F, -6.1F, 1.42F, 0.92F, 4.3F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.68F, -9.2F, 0.85F, 0.85F, 2.3F);
        rotBox(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 1.25F, -10.4F, 0.95F, 1.45F, 0.95F, 25, 0, 0);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 0.8F, -11.4F, 0.78F, 0.78F, 6.2F);
        box(ps, vc, light, ov, T_STEEL_CHROME, 0, 0.8F, -14.65F, 0.96F, 0.96F, 1.1F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 2.52F, -3.2F, 1.15F, 0.52F, 1.5F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_GREEN, -0.28F, 2.86F, -2.5F, 0.16F, 0.16F, 0.1F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_GREEN,  0.28F, 2.86F, -2.5F, 0.16F, 0.16F, 0.1F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 1.95F, -13.5F, 0.45F, 1.85F, 0.75F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, -0.45F, 2.65F, -13.5F, 0.18F, 0.8F, 0.55F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK,  0.45F, 2.65F, -13.5F, 0.18F, 0.8F, 0.55F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_RED, 0, 2.86F, -13.5F, 0.16F, 0.25F, 0.16F);

        ps.pushPose();
        ps.translate(0, 0, slide * 2.5F * S);
        box(ps, vc, light, ov, T_STEEL_CHROME, 0.92F, 1.45F, -1.6F, 0.28F, 0.65F, 2.6F);
        box(ps, vc, light, ov, T_STEEL_CHROME, 1.42F, 1.45F, -2.35F, 0.95F, 0.35F, 0.42F);
        ps.popPose();

        if (magVis) {
            ps.pushPose();
            ps.translate(0, magY * S, -magY * 0.18F * S);
            ps.mulPose(Axis.XP.rotationDegrees(-magY * 2.8F));
            rotBox(ps, vc, light, ov, T_GUNMETAL_DARK, 0, -1.35F, -2.75F, 1.28F, 2.6F, 2.05F, -12, 0, 0);
            rotBox(ps, vc, light, ov, T_GUNMETAL_DARK, 0, -3.55F, -3.35F, 1.26F, 2.5F, 2.02F, -24, 0, 0);
            rotBox(ps, vc, light, ov, T_GUNMETAL_MID,  0, -5.55F, -4.35F, 1.24F, 2.2F, 2.0F,  -36, 0, 0);
            rotBox(ps, vc, light, ov, T_BRASS, 0, -0.1F, -2.5F, 0.7F, 0.45F, 1.3F, -12, 0, 0);
            ps.popPose();
        }
    }

    private static void renderM4A1(PoseStack ps, VertexConsumer vc, int light, int ov,
                                   float slide, float magY, boolean magVis) {
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 0.9F, -0.4F, 1.85F, 2.2F, 6.7F);
        box(ps, vc, light, ov, T_PICATINNY, 0, 2.1F, -0.4F, 1.15F, 0.32F, 6.6F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.45F, 5.5F, 1.15F, 1.15F, 5.8F);
        box(ps, vc, light, ov, T_TAN, 0, 0.75F, 7.6F, 1.65F, 2.95F, 3.6F);
        box(ps, vc, light, ov, T_POLYMER, 0, 0.55F, 9.55F, 1.72F, 3.25F, 0.55F);
        box(ps, vc, light, ov, T_PICATINNY, 0, 1.05F, -7.0F, 1.92F, 1.98F, 6.6F);
        box(ps, vc, light, ov, T_TAN, -1.02F, 1.05F, -7.0F, 0.24F, 0.85F, 5.2F);
        box(ps, vc, light, ov, T_TAN,  1.02F, 1.05F, -7.0F, 0.24F, 0.85F, 5.2F);
        rotBox(ps, vc, light, ov, T_GRIP, 0, -0.55F, -7.4F, 1.12F, 2.1F, 1.25F, -22, 0, 0);
        rotBox(ps, vc, light, ov, T_GRIP, 0, -1.65F, 2.0F, 1.32F, 3.6F, 1.65F, 18, 0, 0);
        box(ps, vc, light, ov, T_POLYMER, 0, -0.65F, 0.2F, 0.6F, 0.25F, 2.1F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.05F, -11.4F, 0.82F, 0.82F, 2.6F);
        box(ps, vc, light, ov, T_POLYMER, 0, 1.05F, -14.15F, 1.28F, 1.28F, 3.6F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.05F, -12.6F, 1.34F, 1.34F, 0.45F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.05F, -15.7F, 1.34F, 1.34F, 0.45F);

        box(ps, vc, light, ov, T_POLYMER, 0, 2.48F, -0.8F, 1.65F, 0.55F, 2.8F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, -0.82F, 3.5F, -0.8F, 0.24F, 1.85F, 2.3F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK,  0.82F, 3.5F, -0.8F, 0.24F, 1.85F, 2.3F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 4.42F, -0.8F, 1.88F, 0.26F, 2.3F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_RED, 0, 3.50F, -0.8F, 0.14F, 0.14F, 0.14F);

        ps.pushPose();
        ps.translate(0, 0, slide * 2.0F * S);
        box(ps, vc, light, ov, T_STEEL_CHROME, 0.94F, 1.35F, -0.8F, 0.16F, 0.65F, 2.1F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.85F, 3.05F, 1.25F, 0.35F, 0.55F);
        ps.popPose();

        if (magVis) {
            ps.pushPose();
            ps.translate(0, magY * S, 0);
            rotBox(ps, vc, light, ov, T_GUNMETAL_MID, 0, -2.2F, -2.4F, 1.22F, 4.4F, 2.15F, -7, 0, 0);
            rotBox(ps, vc, light, ov, T_TAN, 0, -4.45F, -2.65F, 1.35F, 0.6F, 2.25F, -7, 0, 0);
            box(ps, vc, light, ov, T_BRASS, 0, -0.05F, -2.2F, 0.72F, 0.45F, 1.35F);
            ps.popPose();
        }
    }

    private static void renderSPAS12(PoseStack ps, VertexConsumer vc, int light, int ov, float pump, float slide) {
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 0.95F, -0.4F, 2.02F, 2.32F, 7.4F);
        rotBox(ps, vc, light, ov, T_GUNMETAL_MID, 0, 0.25F, 5.8F, 1.55F, 1.35F, 5.8F, -8, 0, 0);
        box(ps, vc, light, ov, T_POLYMER, 0, -0.35F, 8.8F, 1.72F, 3.1F, 0.65F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 2.35F, 1.4F, 1.65F, 0.32F, 6.2F);
        rotBox(ps, vc, light, ov, T_GRIP, 0, -1.7F, 2.3F, 1.42F, 3.8F, 1.75F, 18, 0, 0);
        box(ps, vc, light, ov, T_POLYMER, 0, -0.65F, 0.4F, 0.65F, 0.25F, 2.2F);
        box(ps, vc, light, ov, T_VENT_BARREL, 0, 1.55F, -8.3F, 1.88F, 1.55F, 8.6F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 1.4F, -12.9F, 1.15F, 1.15F, 2.2F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 0.1F, -8.4F, 1.05F, 1.05F, 8.8F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 0.75F, -12.4F, 1.32F, 2.0F, 0.65F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, -0.38F, 2.68F, -1.8F, 0.22F, 0.45F, 0.35F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK,  0.38F, 2.68F, -1.8F, 0.22F, 0.45F, 0.35F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_GREEN, -0.38F, 2.70F, -1.62F, 0.14F, 0.14F, 0.08F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_GREEN,  0.38F, 2.70F, -1.62F, 0.14F, 0.14F, 0.08F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 2.48F, -13.4F, 0.28F, 0.52F, 0.45F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_RED, 0, 2.70F, -13.4F, 0.18F, 0.2F, 0.18F);

        ps.pushPose();
        ps.translate(0, 0, Math.max(slide, pump) * 2.2F * S);
        box(ps, vc, light, ov, T_STEEL_CHROME, 1.02F, 1.3F, -1.3F, 0.18F, 0.75F, 2.4F);
        ps.popPose();

        ps.pushPose();
        ps.translate(0, 0, pump * 3.0F * S);
        box(ps, vc, light, ov, T_GRIP, 0, -0.05F, -7.8F, 2.22F, 1.55F, 4.9F);
        for (int i = 0; i < 5; i++) {
            box(ps, vc, light, ov, T_POLYMER, 0, -0.05F, -9.8F + i * 0.95F, 2.32F, 1.62F, 0.28F);
        }
        ps.popPose();
    }

    private static void renderAWP(PoseStack ps, VertexConsumer vc, int light, int ov,
                                  float bolt, float magY, boolean magVis) {
        box(ps, vc, light, ov, T_OLIVE, 0, 0.55F, -0.5F, 2.02F, 2.05F, 8.2F);
        box(ps, vc, light, ov, T_OLIVE, 0, 0.65F, -7.2F, 1.88F, 1.72F, 5.8F);
        box(ps, vc, light, ov, T_OLIVE, 0, 0.8F, 6.2F, 1.82F, 1.15F, 6.8F);
        box(ps, vc, light, ov, T_OLIVE, 0, -1.25F, 6.5F, 1.65F, 1.05F, 6.2F);
        box(ps, vc, light, ov, T_OLIVE, 0, -0.2F, 8.9F, 1.82F, 3.15F, 1.8F);
        box(ps, vc, light, ov, T_POLYMER, 0, 1.75F, 6.4F, 1.72F, 0.85F, 3.4F);
        box(ps, vc, light, ov, T_POLYMER, 0, -0.2F, 10.0F, 1.88F, 3.25F, 0.65F);
        rotBox(ps, vc, light, ov, T_GRIP, 0, -1.2F, 2.7F, 1.48F, 3.2F, 1.75F, 15, 0, 0);

        box(ps, vc, light, ov, T_GUNMETAL_DARK, -0.85F, -0.55F, -7.5F, 0.45F, 0.45F, 4.8F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK,  0.85F, -0.55F, -7.5F, 0.45F, 0.45F, 4.8F);

        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 1.5F, -1.2F, 1.72F, 1.15F, 7.0F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.32F, -14.5F, 0.92F, 0.92F, 10.2F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 1.32F, -20.1F, 1.68F, 1.25F, 1.65F);
        box(ps, vc, light, ov, T_POLYMER, 0, 1.32F, -20.1F, 1.74F, 0.55F, 0.45F);

        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 2.55F, -2.8F, 1.25F, 1.15F, 0.85F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 2.55F,  0.6F, 1.25F, 1.15F, 0.85F);
        box(ps, vc, light, ov, T_POLYMER, 0, 3.7F, -1.2F, 1.38F, 1.38F, 7.6F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 3.7F, -6.2F, 1.95F, 1.95F, 3.0F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 3.7F,  3.2F, 1.68F, 1.68F, 1.8F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 4.68F, -1.1F, 0.72F, 0.65F, 0.72F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0.98F, 3.7F, -1.1F, 0.65F, 0.72F, 0.72F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_SCOPE_LENS, 0, 3.7F, -7.72F, 1.58F, 1.58F, 0.08F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_SCOPE_LENS, 0, 3.7F,  4.12F, 1.32F, 1.32F, 0.08F);

        ps.pushPose();
        ps.translate(0.95F * S, 1.55F * S, (1.4F + bolt * 2.2F) * S);
        ps.mulPose(Axis.ZP.rotationDegrees(bolt * 52.0F));
        box(ps, vc, light, ov, T_STEEL_CHROME, 0.55F, 0, 0, 1.25F, 0.34F, 0.34F);
        box(ps, vc, light, ov, T_POLYMER, 1.25F, 0, 0, 0.62F, 0.62F, 0.62F);
        ps.popPose();

        if (magVis) {
            ps.pushPose();
            ps.translate(0, magY * S, 0);
            box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, -1.65F, -2.0F, 1.35F, 2.75F, 2.75F);
            box(ps, vc, light, ov, T_BRASS, 0, -0.2F, -2.0F, 0.75F, 0.45F, 1.8F);
            ps.popPose();
        }
    }

    private static void renderMinigun(PoseStack ps, VertexConsumer vc, int light, int ov, float spinAngle) {
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 0.4F, 1.2F, 3.85F, 3.85F, 6.8F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 0.4F, 4.8F, 3.25F, 3.25F, 1.2F);
        box(ps, vc, light, ov, T_POLYMER, 0, 3.55F, -1.8F, 3.4F, 0.65F, 0.85F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, -1.55F, 2.2F, -1.8F, 0.55F, 2.6F, 0.75F);
        box(ps, vc, light, ov, T_GUNMETAL_MID,  1.55F, 2.2F, -1.8F, 0.55F, 2.6F, 0.75F);
        box(ps, vc, light, ov, T_GRIP, 0, 0.4F, 6.4F, 3.2F, 0.65F, 0.65F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, -1.35F, 0.4F, 5.6F, 0.45F, 0.65F, 1.4F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK,  1.35F, 0.4F, 5.6F, 0.45F, 0.65F, 1.4F);
        box(ps, vc, light, ov, T_VENT_BARREL, 0, 0.4F, -3.2F, 4.1F, 4.1F, 2.4F);
        box(ps, vc, light, ov, T_OLIVE, -2.55F, -2.45F, 0.5F, 3.2F, 3.6F, 4.4F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, -2.55F, -2.45F, -1.75F, 2.8F, 3.2F, 0.4F);
        rotBox(ps, vc, light, ov, T_BRASS, -1.65F, -0.55F, 0.4F, 1.2F, 1.65F, 1.9F, 0, 0, -28);

        ps.pushPose();
        ps.translate(0, 0.4F * S, 0);
        ps.mulPose(Axis.ZP.rotationDegrees(spinAngle));
        float r = 1.32F;
        for (int i = 0; i < 6; i++) {
            float rad = (float) Math.toRadians(i * 60.0);
            float bx = Mth.cos(rad) * r;
            float by = Mth.sin(rad) * r;
            box(ps, vc, light, ov, (i % 2 == 0) ? T_STEEL_CHROME : T_GUNMETAL_MID,
                    bx, by, -9.2F, 0.62F, 0.62F, 12.2F);
        }
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 0, -7.8F, 3.55F, 3.55F, 0.72F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 0, -13.6F, 3.55F, 3.55F, 0.85F);
        ps.popPose();
    }

    private static void renderRPG7(PoseStack ps, VertexConsumer vc, int light, int ov,
                                   boolean showWarhead, float warheadSlide) {
        box(ps, vc, light, ov, T_OLIVE, 0, 1.2F, -1.0F, 2.25F, 2.25F, 17.4F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 1.2F, -9.7F, 2.55F, 2.55F, 0.95F);
        box(ps, vc, light, ov, T_WOOD_DARK, 0, 1.2F, 1.6F, 2.75F, 2.75F, 6.6F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.2F, -1.2F, 2.86F, 2.86F, 0.42F);
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.2F,  4.4F, 2.86F, 2.86F, 0.42F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 1.2F, 8.6F, 2.65F, 2.65F, 2.2F);
        box(ps, vc, light, ov, T_GUNMETAL_MID,  0, 1.2F, 10.6F, 3.35F, 3.35F, 2.0F);
        box(ps, vc, light, ov, T_POLYMER,       0, 1.2F, 11.7F, 3.55F, 3.55F, 0.45F);
        rotBox(ps, vc, light, ov, T_WOOD_DARK, 0, -1.2F, -3.2F, 1.28F, 3.4F, 1.55F, 16, 0, 0);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, -0.35F, -4.6F, 0.55F, 0.25F, 2.1F);
        rotBox(ps, vc, light, ov, T_WOOD_DARK, 0, -1.1F,  2.2F, 1.28F, 3.1F, 1.5F, -12, 0, 0);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, -1.65F, 2.35F, -2.2F, 1.15F, 1.15F, 3.4F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_SCOPE_LENS, -1.65F, 2.35F, -3.92F, 0.82F, 0.82F, 0.08F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 2.95F, -8.5F, 0.35F, 1.45F, 0.45F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_RED, 0, 3.42F, -8.5F, 0.22F, 0.22F, 0.22F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 2.95F, -2.5F, 0.95F, 1.25F, 0.35F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_GREEN, -0.3F, 3.40F, -2.3F, 0.16F, 0.16F, 0.1F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_GLOW_GREEN,  0.3F, 3.40F, -2.3F, 0.16F, 0.16F, 0.1F);

        if (showWarhead) {
            ps.pushPose();
            ps.translate(0, 0, -warheadSlide * 9.5F * S);
            box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.2F, -10.8F, 1.55F, 1.55F, 2.2F);
            box(ps, vc, light, ov, T_OLIVE,        0, 1.2F, -12.6F, 3.45F, 3.45F, 2.6F);
            box(ps, vc, light, ov, T_BRASS,        0, 1.2F, -12.6F, 3.55F, 3.55F, 0.52F);
            box(ps, vc, light, ov, T_OLIVE,        0, 1.2F, -14.6F, 2.45F, 2.45F, 1.8F);
            box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 1.2F, -15.9F, 1.35F, 1.35F, 1.2F);
            box(ps, vc, light, ov, T_BRASS,        0, 1.2F, -16.8F, 0.65F, 0.65F, 0.95F);
            ps.popPose();
        }
    }

    public static void renderRocket3D(PoseStack ps, MultiBufferSource buffer, int light) {
        VertexConsumer vc = buffer.getBuffer(RenderType.entityCutoutNoCull(ATLAS));
        int ov = net.minecraft.client.renderer.texture.OverlayTexture.NO_OVERLAY;
        box(ps, vc, light, ov, T_GUNMETAL_MID, 0, 0, -4.5F, 1.0F, 1.0F, 6.0F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 0, -7.2F, 3.6F, 0.25F, 1.8F);
        box(ps, vc, light, ov, T_GUNMETAL_DARK, 0, 0, -7.2F, 0.25F, 3.6F, 1.8F);
        box(ps, vc, light, ov, T_OLIVE, 0, 0, 0.2F, 3.2F, 3.2F, 3.2F);
        box(ps, vc, light, ov, T_BRASS, 0, 0, 0.2F, 3.3F, 3.3F, 0.55F);
        box(ps, vc, light, ov, T_OLIVE, 0, 0, 2.6F, 2.1F, 2.1F, 1.8F);
        box(ps, vc, light, ov, T_BRASS, 0, 0, 4.1F, 0.75F, 0.75F, 1.4F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, -8.8F, 1.6F, 1.6F, 2.4F);
    }

    public static void renderBullet3D(PoseStack ps, MultiBufferSource buffer) {
        VertexConsumer vc = buffer.getBuffer(RenderType.entityCutoutNoCull(ATLAS));
        int ov = net.minecraft.client.renderer.texture.OverlayTexture.NO_OVERLAY;
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_BRASS, 0, 0, 0, 0.45F, 0.45F, 2.6F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, -1.4F, 0.35F, 0.35F, 2.2F);
    }

    private static void renderMuzzleFlash(PoseStack ps, VertexConsumer vc, float y, float z, float size, float alpha, float angle) {
        int ov = net.minecraft.client.renderer.texture.OverlayTexture.NO_OVERLAY;
        float sc = size * (0.65F + 0.55F * alpha);
        ps.pushPose();
        ps.translate(0, y * S, (z - 0.8F) * S);
        ps.mulPose(Axis.ZP.rotationDegrees(angle));
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, 0, sc * 2.2F, sc * 0.45F, sc * 0.35F);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, 0, sc * 0.45F, sc * 2.2F, sc * 0.35F);
        rotBox(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, 0, sc * 1.6F, sc * 0.35F, sc * 0.35F, 0, 0, 45);
        rotBox(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, 0, sc * 1.6F, sc * 0.35F, sc * 0.35F, 0, 0, -45);
        box(ps, vc, LightTexture.FULL_BRIGHT, ov, T_MUZZLE_FLASH, 0, 0, -sc * 0.5F, sc * 0.55F, sc * 0.55F, sc * 1.5F);
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

    private static void box(PoseStack ps, VertexConsumer vc, int light, int ov, int tile,
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
        quad(vc, m, n, x1, y0, z1, x1, y0, z0, x1, y1, z0, x1, y1, z1, u0, v0, u1, v1, 230, light, ov, 1, 0, 0);
    }

    private static void quad(VertexConsumer vc, Matrix4f m, Matrix3f n,
                             float x0, float y0, float z0,
                             float x1, float y1, float z1,
                             float x2, float y2, float z2,
                             float x3, float y3, float z3,
                             float u0, float v0, float u1, float v1,
                             int shade, int light, int ov,
                             float nx, float ny, float nz) {
        vc.vertex(m, x0, y0, z0).color(shade, shade, shade, 255).uv(u0, v1).overlayCoords(ov).uv2(light).normal(n, nx, ny, nz).endVertex();
        vc.vertex(m, x1, y1, z1).color(shade, shade, shade, 255).uv(u1, v1).overlayCoords(ov).uv2(light).normal(n, nx, ny, nz).endVertex();
        vc.vertex(m, x2, y2, z2).color(shade, shade, shade, 255).uv(u1, v0).overlayCoords(ov).uv2(light).normal(n, nx, ny, nz).endVertex();
        vc.vertex(m, x3, y3, z3).color(shade, shade, shade, 255).uv(u0, v0).overlayCoords(ov).uv2(light).normal(n, nx, ny, nz).endVertex();
    }
}
EOF

# ---------------- JAVA: ITEM RENDERER ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/client/GunItemRenderer.java
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
        super(Minecraft.getInstance().getBlockEntityRenderDispatcher(),
              Minecraft.getInstance().getEntityModels());
    }

    @Override
    public void renderByItem(ItemStack stack, ItemDisplayContext ctx, PoseStack ps,
                             MultiBufferSource buffer, int light, int overlay) {
        if (!(stack.getItem() instanceof GunItem gun)) return;
        GunType type = gun.getType();
        Minecraft mc = Minecraft.getInstance();
        boolean firstPerson = ctx == ItemDisplayContext.FIRST_PERSON_RIGHT_HAND
                           || ctx == ItemDisplayContext.FIRST_PERSON_LEFT_HAND;

        if (firstPerson && type.isSniper && GunAnimationEngine.adsProgress > 0.85F) {
            return;
        }

        int ammo = gun.getAmmo(stack);
        boolean reloading = mc.level != null && gun.isReloading(stack, mc.level.getGameTime());

        ps.pushPose();
        ps.translate(0.5F, 0.5F, 0.5F);

        switch (ctx) {
            case FIRST_PERSON_RIGHT_HAND, FIRST_PERSON_LEFT_HAND -> {
                // Posicionamento controlado por GunAnimationEngine
            }
            case THIRD_PERSON_RIGHT_HAND, THIRD_PERSON_LEFT_HAND -> {
                ps.translate(0.0F, 0.06F, 0.08F);
                ps.scale(0.82F, 0.82F, 0.82F);
            }
            case GUI -> {
                float scale = switch (type) {
                    case GLOCK19 -> 1.05F;
                    case AWP_SNIPER, RPG7 -> 0.44F;
                    case MINIGUN -> 0.50F;
                    default -> 0.54F;
                };
                float zShift = switch (type) {
                    case GLOCK19 -> 0.05F;
                    case AWP_SNIPER -> 0.20F;
                    case RPG7 -> 0.05F;
                    default -> 0.12F;
                };
                ps.translate(0.0F, -0.04F, 0.0F);
                ps.mulPose(Axis.ZP.rotationDegrees(28.0F));
                ps.mulPose(Axis.YP.rotationDegrees(-78.0F));
                ps.mulPose(Axis.XP.rotationDegrees(10.0F));
                ps.scale(scale, scale, scale);
                ps.translate(0.0F, 0.0F, zShift);
            }
            case GROUND -> {
                ps.translate(0.0F, 0.14F, 0.0F);
                ps.scale(0.62F, 0.62F, 0.62F);
            }
            case FIXED -> {
                ps.translate(0.0F, -0.04F, 0.0F);
                ps.mulPose(Axis.YP.rotationDegrees(90.0F));
                float s = (type == GunType.GLOCK19) ? 1.0F : 0.55F;
                ps.scale(s, s, s);
            }
            default -> ps.scale(0.75F, 0.75F, 0.75F);
        }

        GunModelGeometry.renderGun(type, ps, buffer, light, overlay, firstPerson, ammo, reloading);
        ps.popPose();
    }
}
EOF

# ---------------- JAVA: ENTITY RENDERERS ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/client/BulletRenderer.java
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
    public void render(BulletEntity entity, float yaw, float partialTick, PoseStack ps,
                       MultiBufferSource buffer, int packedLight) {
        ps.pushPose();
        float yRot = Mth.lerp(partialTick, entity.yRotO, entity.getYRot());
        float xRot = Mth.lerp(partialTick, entity.xRotO, entity.getXRot());
        ps.mulPose(Axis.YP.rotationDegrees(yRot));
        ps.mulPose(Axis.XP.rotationDegrees(-xRot));
        GunModelGeometry.renderBullet3D(ps, buffer);
        ps.popPose();
        super.render(entity, yaw, partialTick, ps, buffer, packedLight);
    }

    @Override
    public ResourceLocation getTextureLocation(BulletEntity entity) {
        return GunModelGeometry.ATLAS;
    }
}
EOF

cat << 'EOF' > src/main/java/com/arsenalmod/client/RocketRenderer.java
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
    public void render(RocketEntity entity, float yaw, float partialTick, PoseStack ps,
                       MultiBufferSource buffer, int packedLight) {
        ps.pushPose();
        float yRot = Mth.lerp(partialTick, entity.yRotO, entity.getYRot());
        float xRot = Mth.lerp(partialTick, entity.xRotO, entity.getXRot());
        ps.mulPose(Axis.YP.rotationDegrees(yRot));
        ps.mulPose(Axis.XP.rotationDegrees(-xRot));
        GunModelGeometry.renderRocket3D(ps, buffer, packedLight);
        ps.popPose();
        super.render(entity, yaw, partialTick, ps, buffer, packedLight);
    }

    @Override
    public ResourceLocation getTextureLocation(RocketEntity entity) {
        return GunModelGeometry.ATLAS;
    }
}
EOF

# ---------------- JAVA: CLIENT MOD EVENTS ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/client/ClientModEvents.java
package com.arsenalmod.client;

import com.arsenalmod.ArsenalMod;
import com.arsenalmod.registry.ModEntities;
import net.minecraft.client.KeyMapping;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import org.lwjgl.glfw.GLFW;

@Mod.EventBusSubscriber(modid = ArsenalMod.MODID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public class ClientModEvents {
    public static final KeyMapping RELOAD_KEY = new KeyMapping(
            "key.arsenalmod.reload",
            GLFW.GLFW_KEY_R,
            "key.categories.arsenalmod"
    );

    @SubscribeEvent
    public static void onRegisterRenderers(EntityRenderersEvent.RegisterRenderers event) {
        event.registerEntityRenderer(ModEntities.BULLET.get(), BulletRenderer::new);
        event.registerEntityRenderer(ModEntities.ROCKET.get(), RocketRenderer::new);
    }

    @SubscribeEvent
    public static void onRegisterKeys(RegisterKeyMappingsEvent event) {
        event.register(RELOAD_KEY);
    }
}
EOF

# ---------------- JAVA: CLIENT FORGE EVENTS (INPUT + ZOOM + HUD + SCOPE) ----------------
cat << 'EOF' > src/main/java/com/arsenalmod/client/ClientForgeEvents.java
package com.arsenalmod.client;

import com.arsenalmod.ArsenalMod;
import com.arsenalmod.item.GunItem;
import com.arsenalmod.item.GunType;
import com.arsenalmod.network.C2SReloadPacket;
import com.arsenalmod.network.C2SShootPacket;
import com.arsenalmod.network.ModNetwork;
import com.arsenalmod.registry.ModItems;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.util.Mth;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.InputEvent;
import net.minecraftforge.client.event.RenderGuiOverlayEvent;
import net.minecraftforge.client.event.ViewportEvent;
import net.minecraftforge.client.gui.overlay.VanillaGuiOverlay;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = ArsenalMod.MODID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
public class ClientForgeEvents {
    private static int localCooldown = 0;
    private static boolean wasAttackDown = false;
    private static boolean attackQueued = false;

    @SubscribeEvent
    public static void onInteraction(InputEvent.InteractionKeyMappingTriggered event) {
        Minecraft mc = Minecraft.getInstance();
        LocalPlayer player = mc.player;
        if (player == null) return;
        if (!(player.getMainHandItem().getItem() instanceof GunItem)) return;

        if (event.isAttack()) {
            event.setCanceled(true);
            event.setSwingHand(false);
            attackQueued = true;
        } else if (event.isUseItem()) {
            event.setCanceled(true);
            event.setSwingHand(false);
        }
    }

    @SubscribeEvent
    public static void onClientTick(TickEvent.ClientTickEvent event) {
        if (event.phase != TickEvent.Phase.END) return;
        Minecraft mc = Minecraft.getInstance();
        LocalPlayer player = mc.player;

        if (localCooldown > 0) localCooldown--;

        if (player == null || mc.screen != null) {
            GunAnimationEngine.isAiming = false;
            wasAttackDown = false;
            attackQueued = false;
            return;
        }

        ItemStack stack = player.getMainHandItem();
        if (!(stack.getItem() instanceof GunItem gun)) {
            GunAnimationEngine.isAiming = false;
            wasAttackDown = false;
            attackQueued = false;
            return;
        }

        GunType type = gun.getType();
        boolean attackDown = mc.options.keyAttack.isDown();
        boolean useDown = mc.options.keyUse.isDown();
        GunAnimationEngine.isAiming = useDown;

        while (ClientModEvents.RELOAD_KEY.consumeClick()) {
            ModNetwork.INSTANCE.sendToServer(new C2SReloadPacket());
        }

        long now = player.level().getGameTime();
        boolean reloading = gun.isReloading(stack, now);
        boolean wantsFire = type.fullAuto
                ? (attackDown || attackQueued)
                : (attackQueued || (attackDown && !wasAttackDown));

        if (wantsFire && !reloading && localCooldown <= 0) {
            int ammo = gun.getAmmo(stack);
            ModNetwork.INSTANCE.sendToServer(new C2SShootPacket(GunAnimationEngine.isAiming));
            if (ammo > 0) {
                GunAnimationEngine.onLocalShot(type, player);
                localCooldown = type.fireCooldown;
            } else {
                localCooldown = 8;
            }
        }

        wasAttackDown = attackDown;
        attackQueued = false;
    }

    @SubscribeEvent
    public static void onRenderTick(TickEvent.RenderTickEvent event) {
        if (event.phase == TickEvent.Phase.START) {
            GunAnimationEngine.updateFrame();
        }
    }

    @SubscribeEvent
    public static void onComputeFov(ViewportEvent.ComputeFov event) {
        Minecraft mc = Minecraft.getInstance();
        LocalPlayer player = mc.player;
        if (player == null) return;
        ItemStack stack = player.getMainHandItem();
        if (!(stack.getItem() instanceof GunItem gun)) return;

        float fovMul = Mth.lerp(GunAnimationEngine.adsProgress, 1.0F, gun.getType().adsFov);
        event.setFOV(event.getFOV() * fovMul);
    }

    @SubscribeEvent
    public static void onRenderGuiPre(RenderGuiOverlayEvent.Pre event) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null) return;
        if (mc.player.getMainHandItem().getItem() instanceof GunItem
                && event.getOverlay() == VanillaGuiOverlay.CROSSHAIR.type()) {
            event.setCanceled(true);
        }
    }

    @SubscribeEvent
    public static void onRenderGuiPost(RenderGuiOverlayEvent.Post event) {
        if (event.getOverlay() != VanillaGuiOverlay.HOTBAR.type()) return;
        Minecraft mc = Minecraft.getInstance();
        LocalPlayer player = mc.player;
        if (player == null || mc.options.hideGui) return;

        ItemStack stack = player.getMainHandItem();
        if (!(stack.getItem() instanceof GunItem gun)) return;

        GuiGraphics gg = event.getGuiGraphics();
        int sw = event.getWindow().getGuiScaledWidth();
        int sh = event.getWindow().getGuiScaledHeight();
        GunType type = gun.getType();
        long now = player.level().getGameTime();
        boolean reloading = gun.isReloading(stack, now);

        if (type.isSniper && GunAnimationEngine.adsProgress > 0.85F) {
            renderSniperScope(gg, sw, sh);
        } else if (GunAnimationEngine.adsProgress < 0.75F) {
            renderDynamicCrosshair(gg, sw, sh, type);
        }

        renderAmmoHud(gg, mc.font, sw, sh, player, stack, gun, reloading, now, event.getPartialTick());
    }

    private static void renderSniperScope(GuiGraphics gg, int sw, int sh) {
        int cx = sw / 2;
        int cy = sh / 2;
        int radius = Math.min(sw, sh) * 42 / 100;
        int black = 0xFF000000;

        gg.fill(0, 0, sw, cy - radius, black);
        gg.fill(0, cy + radius, sw, sh, black);
        gg.fill(0, cy - radius, cx - radius, cy + radius, black);
        gg.fill(cx + radius, cy - radius, sw, cy + radius, black);

        for (int dy = -radius; dy <= radius; dy++) {
            int dx = (int) Math.sqrt((double) radius * radius - (double) dy * dy);
            int y = cy + dy;
            gg.fill(cx - radius, y, cx - dx, y + 1, black);
            gg.fill(cx + dx, y, cx + radius, y + 1, black);
        }

        gg.fill(cx - radius, cy, cx + radius, cy + 1, 0xCC000000);
        gg.fill(cx, cy - radius, cx + 1, cy + radius, 0xCC000000);
        gg.fill(cx - radius, cy - 1, cx - radius / 2, cy + 2, black);
        gg.fill(cx + radius / 2, cy - 1, cx + radius, cy + 2, black);
        gg.fill(cx - 1, cy + radius / 2, cx + 2, cy + radius, black);

        for (int i = 1; i <= 4; i++) {
            int off = i * (radius / 8);
            gg.fill(cx - off, cy - 3, cx - off + 1, cy + 4, 0xDD000000);
            gg.fill(cx + off, cy - 3, cx + off + 1, cy + 4, 0xDD000000);
            gg.fill(cx - 3, cy + off, cx + 4, cy + off + 1, 0xDD000000);
        }

        gg.fill(cx - 1, cy - 1, cx + 2, cy + 2, 0xFFFF2222);
    }

    private static void renderDynamicCrosshair(GuiGraphics gg, int sw, int sh, GunType type) {
        int cx = sw / 2;
        int cy = sh / 2;
        float alphaF = 1.0F - (GunAnimationEngine.adsProgress / 0.75F);
        int a = Mth.clamp((int) (alphaF * 230.0F), 0, 230);
        if (a < 10) return;

        int white = (a << 24) | 0xFFFFFF;
        int shadow = ((a / 2) << 24);
        int gap = 4 + (int) (type.spread * 2.2F + GunAnimationEngine.recoilZ * 38.0F);
        int len = 6;

        gg.fill(cx - 1, cy - gap - len - 1, cx + 2, cy - gap + 1, shadow);
        gg.fill(cx, cy - gap - len, cx + 1, cy - gap, white);
        gg.fill(cx - 1, cy + gap, cx + 2, cy + gap + len + 2, shadow);
        gg.fill(cx, cy + gap + 1, cx + 1, cy + gap + len + 1, white);
        gg.fill(cx - gap - len - 1, cy - 1, cx - gap + 1, cy + 2, shadow);
        gg.fill(cx - gap - len, cy, cx - gap, cy + 1, white);
        gg.fill(cx + gap, cy - 1, cx + gap + len + 2, cy + 2, shadow);
        gg.fill(cx + gap + 1, cy, cx + gap + len + 1, cy + 1, white);
        gg.fill(cx, cy, cx + 1, cy + 1, white);
    }

    private static void renderAmmoHud(GuiGraphics gg, Font font, int sw, int sh, LocalPlayer player,
                                      ItemStack stack, GunItem gun, boolean reloading, long now, float partialTick) {
        GunType type = gun.getType();
        int ammo = gun.getAmmo(stack);
        int reserve = countReserve(player, type);
        String reserveTxt = player.isCreative() ? "INF" : String.valueOf(reserve);

        int boxW = 126;
        int boxH = reloading ? 44 : 34;
        int x = sw - boxW - 10;
        int y = sh - boxH - 10;

        gg.fill(x, y, x + boxW, y + boxH, 0x9910141A);
        gg.fill(x, y, x + 3, y + boxH, ammo == 0 ? 0xFFE53935 : 0xFFFFB300);

        gg.drawString(font, type.displayName, x + 8, y + 5, 0xFFE0E6ED, true);

        int ammoColor = ammo == 0 ? 0xFFFF5252 : (ammo <= Math.max(1, type.maxAmmo / 4) ? 0xFFFFCA28 : 0xFFFFFFFF);
        String ammoLine = ammo + " / " + type.maxAmmo + "  [" + reserveTxt + "]";
        gg.drawString(font, ammoLine, x + 8, y + 18, ammoColor, true);

        if (reloading) {
            float prog = gun.getReloadProgress(stack, now, partialTick);
            int barX = x + 8;
            int barY = y + 32;
            int barW = boxW - 16;
            gg.fill(barX, barY, barX + barW, barY + 6, 0xCC263238);
            gg.fill(barX, barY, barX + (int) (barW * prog), barY + 6, 0xFFFFCA28);
        }
    }

    private static int countReserve(LocalPlayer player, GunType type) {
        Item ammoItem = ModItems.getAmmoItem(type.ammoKind);
        int items = 0;
        for (ItemStack inv : player.getInventory().items) {
            if (inv.is(ammoItem) && !inv.isEmpty()) {
                items += inv.getCount();
            }
        }
        return items * type.roundsPerAmmoItem;
    }
}
EOF

echo "[4/5] Gerando texturas PNG (atlas 3D 256x256 + icones de municao)..."

base64 -d << 'B64_EOF' > src/main/resources/assets/arsenalmod/textures/entity/weapons_atlas.png
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
CEAgEAgBCAQCIQCBQCAEIBAIhAAEAoEQgEAgEAIQCARCAAKBQAhAIBAIAQgEAiEAgUAgBCAQCIQA
BAKBEIBAIAQgEAiEAAQCgRCAQCAQAhAIBEIAAoFACEAgEAgBCAQCIQCBQCAEIBAIhAAEAoEQgEAg
EAIQCARCAAKBQAhAIBAIAQgEAiEAgUAgBCAQCIQABAKBEIBAIBACEAgEQgACgUAIQCAQCAEIBAIh
AIFAIAQgEAiEAAQCgRCAQCAQAhAIBEIAAoFACEAgEAgBCAQCIQCBQCAEIBAIhAAEAoEQgEAgEAIQ
CARCAAKBEIBAIBACEAgEQgACgUAIQCAQCAEIBAIhAIFAIAQgEAiEAAQCgRCAQCAQAhAIBEIAAoFA
CEAgEAgBCAQCIQCBQCAEIBAIhAAEAoEQgEAgEAIQCARCAAKBQAhAIBAIAQgEAiEAgUAgBCAQCIQA
BAKBEIBAIBACEAgEQgACgUAIQCAQCAEIBAIhAIFAIAQgEAiEAAQCgRCAQCAQAhAIBEIAAoFACEAg
EAgBCARCAAKBQAhAIBAIAQgEAiEAgUAgBCAQCIQABALB/wfxfwF5tOH+HJo5owAAAABJRU5ErkJg
gg==
B64_EOF

base64 -d << 'B64_EOF' > src/main/resources/assets/arsenalmod/textures/item/pistol_ammo.png
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAU0lEQVR42mNgGJ7gzkSf/1tStP4T
EmNgYGBgwmbAi6cvGASEuAiK4TSAFEB9AypiZP6js7GJ4XWBgAUfg4AFH0GxQRoGdDeABZvgknW3
iBIbHAAAbtgdN2w9xJEAAAAASUVORK5CYII=
B64_EOF

base64 -d << 'B64_EOF' > src/main/resources/assets/arsenalmod/textures/item/rifle_ammo.png
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAPUlEQVR42mNgGFTg2SS//6TwGRgY
GJiQOQ/uPWIghY9hADlgEBkwrUTlv4CDCMO1DS7/ieEPxzAYwQZQDACSeiBWUlwoGAAAAABJRU5E
rkJggg==
B64_EOF

base64 -d << 'B64_EOF' > src/main/resources/assets/arsenalmod/textures/item/shotgun_shell.png
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAa0lEQVR42mNgGPKAEZlTICDwH5k/
4cMHRnziDAwMDEzoJlbb2DCECAgwECvORKkXRg1gYGBB5giFCTBMZ7jCwCDFwCDEIMDAMOsDXnGs
LogK0mCICtJgIFacul5gYGBgWLbuBlaFuMQHHgAAbEcZ4oJYluoAAAAASUVORK5CYII=
B64_EOF

base64 -d << 'B64_EOF' > src/main/resources/assets/arsenalmod/textures/item/sniper_ammo.png
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAbUlEQVR42mNgGHJgV4bO/9czgv7D
+EykamZgYGA4f+EWA8kGwDQzMDAwuM24wkiSAbg0E2XAlytlODUzMDAwMBLS/OTeBThfw28Xhnom
YjXjAkzEasZmO1YDSNGMYQCpmjEMIFUz3kAkRvPgAACPND2wJoN/0QAAAABJRU5ErkJggg==
B64_EOF

base64 -d << 'B64_EOF' > src/main/resources/assets/arsenalmod/textures/item/rocket_ammo.png
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAk0lEQVR42mNgGJLgw6W8/2RrPrzI
BUUzCzGafJLM/jMwMDCUO/AxdB74hCLHRKxmBgYGDM0EDXiwy4ugX5nw2Zyz4g3DlAgR0g1Adja6
IVvmnWIkORBhhii4bWMk6IKohAys/samGcUFjm5+/yWlpLC6AN3ZWA2QlJJieP7sGYOklBReDVi9
AHM2zBCyAC6/0xwAAMn2NgAhIBL0AAAAAElFTkSuQmCC
B64_EOF

echo "[5/5] Compilando mod Forge 1.20.1 para .jar (com reobfJar)..."
"$GRADLE_BIN" build --no-daemon

JAR_FILE="$(find build/libs -maxdepth 1 -name 'arsenalmod-*.jar' ! -name '*-sources.jar' | head -n 1)"
if [ -n "$JAR_FILE" ] && [ -f "$JAR_FILE" ]; then
    cp "$JAR_FILE" "$START_DIR/arsenalmod-1.0.0.jar"
    echo "=================================================="
    echo " SUCESSO! Mod compilado em:"
    echo " $START_DIR/arsenalmod-1.0.0.jar"
    echo "=================================================="
else
    echo "ERRO: Arquivo .jar nao encontrado em build/libs!"
    exit 1
fi
