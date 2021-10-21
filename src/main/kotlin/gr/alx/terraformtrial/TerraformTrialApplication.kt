package gr.alx.terraformtrial

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.core.env.Environment
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import java.net.InetAddress

@SpringBootApplication
class TerraformTrialApplication

fun main(args: Array<String>) {
    runApplication<TerraformTrialApplication>(*args)
}

@RestController
class TestController(private val environment: Environment) {
    @GetMapping("/hello")

    fun hello(): AppInfo {
        // obtain a hostname. First try to get the host name from docker container (from the "HOSTNAME" environment variable)
        var hostName = System.getenv("HOSTNAME")

        val hostAddress = InetAddress.getLoopbackAddress();
        // get the os name
        val os = System.getProperty("os.name")

        // if the application is not running in a docker container, we can to obtain the hostname using the "java.net.InetAddress" class
        if (hostName == null || hostName.isEmpty()) {
            hostName = try {
                val addr = InetAddress.getLocalHost()
                addr.hostName
            } catch (e: Exception) {
                System.err.println(e)
                "Unknown"
            }
        }

        return AppInfo("Sample Java Spring Boot app", hostName, os)
    }
}
