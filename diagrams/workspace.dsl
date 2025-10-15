workspace "HiveR" "You HRownik" {
    model {
        employee = person "Employee"
        manager = person "Manager"
        admin = person "Admin"

        hiver_system = softwareSystem "HiveR" "HRownik"

        aws_sns = softwareSystem "AWS SNS" "Email and push notification handling."
        iot_devices = externalDevice "IoT" "Various IoT devices" // custom class for iot

        // Systems
        employee -> hiver_system "Manages work duties using"
        manager -> hiver_system "Manages workforce using"
        admin -> hiver_system "Administrates the system through"

        hiver_system -> aws_sns "Sends emails to users using"
        iot_devices -> hiver_system "Notifies about in-office presence change"

        aws_sns -> employee "Sends push notifications and emails to"
        aws_sns -> admin "Sends emails to"

        // Presence flow
        employee -> hiver_system "Manages in-office presence using"
        hiver_system -> iot_devices "Papa yaya"
        iot_devices -> hiver_system "Yada yada"

    }



//    views {
//        systemContext hiver_system "Diagram1" {
//            include *
//        }
//    }
}