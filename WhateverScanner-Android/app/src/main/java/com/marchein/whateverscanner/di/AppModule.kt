package com.marchein.whateverscanner.di

import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * Hilt module for application-scoped bindings.
 *
 * All services and repositories in this app use constructor injection
 * (`@Inject` + `@Singleton`), so no explicit `@Provides` methods are required
 * yet. This module is the place to add bindings for interfaces or third-party
 * types that cannot be constructor-injected.
 */
@Module
@InstallIn(SingletonComponent::class)
object AppModule
