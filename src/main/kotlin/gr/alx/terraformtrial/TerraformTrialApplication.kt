package gr.alx.terraformtrial

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController

@SpringBootApplication
class TerraformTrialApplication

fun main(args: Array<String>) {
    runApplication<TerraformTrialApplication>(*args)
}

@RestController
class TestController {
    @GetMapping("/hello")
    fun hello(): String {
        return "hello"
    }
}
