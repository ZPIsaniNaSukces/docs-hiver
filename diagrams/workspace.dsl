workspace "HiveR" "You HRownik" {
    model {
        // Actors
        employee = person "Employee" "A registered employee of a given company."
        manager = person "Manager" "A registered manager of a given company."
        admin = person "Admin" "An owner of a given company."

        hiver_system = softwareSystem "HiveR" "HRownik" {
            backend = container "Backend" {

                bus = component "Bus" {
                    technology "Kafka"
                    tags "Bus"
                }

                // Main
                main = component "Main" {
                    technology "NestJS"
                }

                mainDb = component "Main Database" {
                    technology "PostgreSQL"
                    tags "Database"
                }

                // Presence microservice
                presence = component "Presence" {
                    technology "NestJS"
                    tags "Microservice"
                }

                presence_db = component "Presence Database" {
                    technology "PostgreSQL"
                    tags "Database"
                }

                // Task microservice
                tasks = component "Tasks" {
                    technology "NestJS"
                    tags "Microservice"
                }

                tasks_db = component "Tasks Database" {
                    technology "PostgreSQL"
                    tags "Database"
                }

                // Authentication microservice
                authentication = component "Authentication" {
                    technology "NestJS"
                    tags "Microservice"
                }

                authentication_db = component "Authentication Database" {
                    technology "PostgreSQL"
                    tags "Database"
                }

                // Employee time tracking
                time_tracker = component "Time Tracker" {
                    technology "NestJS"
                    tags "Microservice"
                }

                time_tracker_db = component "Time Tracker Database" {
                    technology "PostgreSQL"
                    tags "Database"
                }

                // Forms
                forms = component "Forms" {
                    technology "NestJS"
                    tags "Microservice"
                }

                forms_db = component "Forms Database" {
                    technology "PostgreSQL"
                    tags "Database"
                }

                // Managing employees
                employee_manager = component "Employee Manager" {
                    technology "NestJS"
                    tags "Microservice"
                }

                employee_manager_db = component "Employee Manager Database" {
                    technology "PostgreSQL"
                    tags "Database"
                }
            }

            mobile = container "Mobile App"{
                tags "Mobile"
            }

            webApp = container "Web App" {

            }
        }

        iot_devices = softwareSystem "IoT" {
            tags "ExternalDevice"
        }

        aws_sns = softwareSystem "AWS SNS" "Email and push notification handling."

        ////////// RELATIONS //////////
        // remember, structurizr has implied relationships, you don't have to reference the hiver system and then a container inside, referencing the container only is enough and structurizr handles the rest 

        ///// actors
        employee -> mobile  
        employee -> hiver_system "Manages in-office presence using"
        manager -> webApp "Manages workforce using"
        admin -> webApp "Administrates the system through"

        ///// software system
        aws_sns -> employee "Sends push notifications and emails to"
        aws_sns -> admin "Sends emails to"
        iot_devices -> mobile "responds"
        hiver_system -> aws_sns "Sends emails to users using"

        ///// webapp
        webApp -> main "Sends events to"

        ///// mobile
        mobile -> iot_devices "prompts"
        mobile -> backend

        ///// backend
        // main
        main -> bus "Sends events to"
        main -> mainDb "Writes to"


        // microservices
        presence -> presence_db "Writes to"
        presence -> bus "Subscribes to"

        tasks -> tasks_db "Writes to"
        tasks -> bus "Subscribes to"

        authentication -> authentication_db "Writes to"
        authentication -> bus "Subscribes to"

        time_tracker -> time_tracker_db "Writes to"
        time_tracker -> bus "Subscribes to"

        employee_manager -> employee_manager_db "Writes to"
        employee_manager -> bus "Subscribes to"

        forms -> forms_db "Writes to"
        forms -> bus "Subscribes to"
    }

    // Note to everyone: autolayout is an absolute garbage, don't use it
    views {
        systemContext hiver_system "Diagram1" {
            include *
        }

        container hiver_system "Diagram2" {
            include *
        }

        component backend "Diagram3"{
            include *
        }

        styles {
            element "Element"{
                color #0773af
                stroke #0773af
                strokeWidth 7
            }

            element "Person" {
                shape person
            }

            element "Boundary" {
                strokeWidth 5
            }

            relationship "Relationship" {
                thickness 5
            }

            element "Database"{
                shape cylinder
            }

            element "Microservice" {
                shape hexagon
            }

            element "Bus" {
                shape pipe
            }

            element "ExternalDevice" {
                shape folder
            }

            element "Mobile" {
                shape MobileDevicePortrait
            }
        }
    }
}