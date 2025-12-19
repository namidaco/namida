package com.msob7y.namida

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

object LauncherIconController {

    fun tryFixLauncherIconIfNeeded() {
        for (icon in LauncherIcon.values()) {
            if (isEnabled(icon)) {
                return
            }
        }
        setIcon(LauncherIcon.DEFAULT)
    }

    fun isEnabled(icon: LauncherIcon): Boolean {
        val ctx = NamidaMainActivity.currentApplicationContext
        if (ctx == null) {
            return false
        }
        val state = ctx.packageManager.getComponentEnabledSetting(icon.getComponentName(ctx))
        return state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                (state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && icon == LauncherIcon.DEFAULT)
    }

    fun setIcon(icon: LauncherIcon) {
        val ctx = NamidaMainActivity.currentApplicationContext
        if (ctx == null) {
            return
        }
        val pm = ctx.packageManager
        for (i in LauncherIcon.values()) {
            val state =
                if (i == icon) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED

            pm.setComponentEnabledSetting(
                i.getComponentName(ctx),
                state,
                PackageManager.DONT_KILL_APP
            )
        }
    }

}


// SPLASH_AUTO_GENERATED START
enum class LauncherIcon(
    val key: String,
    val foreground: Int
) {
	DEFAULT("DefaultIcon", R.mipmap.ic_launcher),
	ENHANCED("EnhancedIcon", R.mipmap.ic_launcher_enhanced),
	HOLLOW("HollowIcon", R.mipmap.ic_launcher_hollow),
	MONET("MonetIcon", R.mipmap.ic_launcher_monet),
	GLOWY("GlowyIcon", R.mipmap.ic_launcher_glowy),
	SHADE("ShadeIcon", R.mipmap.ic_launcher_shade),
	MINI("MiniIcon", R.mipmap.ic_launcher_mini),
	SPOOKY("SpookyIcon", R.mipmap.ic_launcher_spooky),
	NAMIWEEN("NamiweenIcon", R.mipmap.ic_launcher_namiween),
	SPACE("SpaceIcon", R.mipmap.ic_launcher_space),
	TIRED("TiredIcon", R.mipmap.ic_launcher_tired),
	EDDY("EddyIcon", R.mipmap.ic_launcher_eddy),
	NAMICHIN("NamichinIcon", R.mipmap.ic_launcher_namichin),
	CUTSIE("CutsieIcon", R.mipmap.ic_launcher_cutsie);

    private var componentName: ComponentName? = null

    fun getComponentName(ctx: Context): ComponentName {
        if (componentName == null) {
            componentName = ComponentName(ctx.packageName, "com.msob7y.namida.$key")
        }
        return componentName!!
    }
}
// SPLASH_AUTO_GENERATED END