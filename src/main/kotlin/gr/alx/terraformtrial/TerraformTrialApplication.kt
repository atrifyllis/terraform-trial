package gr.alx.terraformtrial

import com.amazonaws.services.ec2.AmazonEC2ClientBuilder
import com.amazonaws.services.ec2.model.DescribeInstancesRequest
import com.amazonaws.services.ec2.model.Instance
import com.amazonaws.services.ec2.model.Reservation
import com.amazonaws.util.EC2MetadataUtils
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

        val publicIp = getPublicIp()

        return AppInfo("Sample Java Spring Boot app", hostName, publicIp, os)
    }

    fun getPublicIp(): String {
        try {
            // Getting instance Id
            val instanceId = EC2MetadataUtils.getInstanceId()


// Getting EC2 private IP
            val privateIP = EC2MetadataUtils.getInstanceInfo().privateIp


// Getting EC2 public IP
            val awsEC2client = AmazonEC2ClientBuilder.defaultClient()
            val publicIP: String = awsEC2client.describeInstances(
                DescribeInstancesRequest()
                    .withInstanceIds(instanceId)
            )
                .reservations
                .stream()
                .map { obj: Reservation -> obj.instances }
                .flatMap { obj: List<Instance> -> obj.stream() }
                .findFirst()
                .map<Any?>(Instance::getPublicIpAddress)
                .orElse("").toString()
            return publicIP
        } catch (e: Exception) {
            return ""
        }
    }
}
