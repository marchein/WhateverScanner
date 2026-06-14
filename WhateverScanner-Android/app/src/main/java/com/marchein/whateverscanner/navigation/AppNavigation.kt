package com.marchein.whateverscanner.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.navigation
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.marchein.whateverscanner.ui.screens.AddServerScreen
import com.marchein.whateverscanner.ui.screens.LaunchScreen
import com.marchein.whateverscanner.ui.screens.MainScreen
import com.marchein.whateverscanner.ui.screens.MainViewModel
import com.marchein.whateverscanner.ui.screens.OnboardingScreen
import com.marchein.whateverscanner.ui.screens.ScanPreviewScreen
import com.marchein.whateverscanner.ui.screens.SettingsScreen

/** Route constants for the navigation graph. */
object Routes {
    const val LAUNCH = "launch"
    const val ONBOARDING = "onboarding"
    const val SCANNER_GRAPH = "scanner"
    const val MAIN = "main"
    const val PREVIEW = "preview"
    const val SETTINGS = "settings"
    const val ADD_SERVER = "add_server"
    const val ARG_SERVER_ID = "serverId"
}

/**
 * App navigation graph.
 *
 * The [Routes.MAIN] and [Routes.PREVIEW] screens live in a nested graph so they
 * can share a single [MainViewModel] instance (holding the in-progress scan).
 */
@Composable
fun AppNavigation() {
    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = Routes.LAUNCH) {
        composable(Routes.LAUNCH) {
            LaunchScreen(
                onFinished = { setupComplete ->
                    val destination = if (setupComplete) Routes.SCANNER_GRAPH else Routes.ONBOARDING
                    navController.navigate(destination) {
                        popUpTo(Routes.LAUNCH) { inclusive = true }
                    }
                }
            )
        }

        composable(Routes.ONBOARDING) {
            OnboardingScreen(
                onComplete = {
                    navController.navigate(Routes.SCANNER_GRAPH) {
                        popUpTo(Routes.ONBOARDING) { inclusive = true }
                    }
                }
            )
        }

        navigation(startDestination = Routes.MAIN, route = Routes.SCANNER_GRAPH) {
            composable(Routes.MAIN) { entry ->
                val parentEntry = remember(entry) {
                    navController.getBackStackEntry(Routes.SCANNER_GRAPH)
                }
                val viewModel = hiltViewModel<MainViewModel>(parentEntry)
                MainScreen(
                    viewModel = viewModel,
                    onOpenSettings = { navController.navigate(Routes.SETTINGS) },
                    onScanReady = { navController.navigate(Routes.PREVIEW) }
                )
            }

            composable(Routes.PREVIEW) { entry ->
                val parentEntry = remember(entry) {
                    navController.getBackStackEntry(Routes.SCANNER_GRAPH)
                }
                val viewModel = hiltViewModel<MainViewModel>(parentEntry)
                ScanPreviewScreen(
                    viewModel = viewModel,
                    onDone = { navController.popBackStack() }
                )
            }
        }

        composable(Routes.SETTINGS) {
            SettingsScreen(
                onBack = { navController.popBackStack() },
                onAddServer = { navController.navigate(Routes.ADD_SERVER) },
                onEditServer = { serverId ->
                    navController.navigate("${Routes.ADD_SERVER}?${Routes.ARG_SERVER_ID}=$serverId")
                }
            )
        }

        composable(
            route = "${Routes.ADD_SERVER}?${Routes.ARG_SERVER_ID}={${Routes.ARG_SERVER_ID}}",
            arguments = listOf(
                navArgument(Routes.ARG_SERVER_ID) {
                    type = NavType.StringType
                    nullable = true
                    defaultValue = null
                }
            )
        ) { entry ->
            val serverId = entry.arguments?.getString(Routes.ARG_SERVER_ID)
            AddServerScreen(
                serverId = serverId,
                onBack = { navController.popBackStack() }
            )
        }
    }
}
