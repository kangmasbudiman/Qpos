import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/pos_controller.dart';
import '../../data/models/customer_model.dart';

class CustomerSelector extends StatelessWidget {
  final POSController controller;

  const CustomerSelector({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedCustomer = controller.selectedCustomer;

      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          border: Border(
            bottom: BorderSide(color: Colors.orange[200]!),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.person, color: Colors.orange[700]),
            SizedBox(width: 12.w),
            Expanded(
              child: selectedCustomer == null
                  ? Text(
                      'No customer selected (General Sale)',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedCustomer.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (selectedCustomer.phone != null)
                          Text(
                            selectedCustomer.phone!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
            ),
            if (selectedCustomer != null)
              IconButton(
                icon: Icon(Icons.close, color: Colors.red),
                onPressed: controller.clearCustomer,
                tooltip: 'Clear customer',
              ),
            ElevatedButton.icon(
              onPressed: () => _showCustomerDialog(context),
              icon: Icon(Icons.person_add, size: 18.sp),
              label: Text(selectedCustomer == null ? 'Select' : 'Change'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showCustomerDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        child: Container(
          width: Get.width * 0.9,
          height: Get.height * 0.7,
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Customer',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              ElevatedButton.icon(
                onPressed: () {
                  Get.back();
                  _showAddCustomerDialog(context);
                },
                icon: Icon(Icons.add),
                label: Text('Add New Customer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(height: 16.h),
              Divider(),
              SizedBox(height: 8.h),
              Expanded(
                child: Obx(() {
                  if (controller.customers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64.sp, color: Colors.grey),
                          SizedBox(height: 16.h),
                          Text('No customers yet'),
                          SizedBox(height: 8.h),
                          TextButton(
                            onPressed: () {
                              Get.back();
                              _showAddCustomerDialog(context);
                            },
                            child: Text('Add your first customer'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: controller.customers.length,
                    itemBuilder: (context, index) {
                      final customer = controller.customers[index];
                      final isSelected = controller.selectedCustomer?.id == customer.id;

                      return Card(
                        color: isSelected ? Colors.orange[50] : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected ? Colors.orange : Colors.blue,
                            child: Text(
                              customer.name[0].toUpperCase(),
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            customer.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: customer.phone != null
                              ? Text(customer.phone!)
                              : null,
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: Colors.orange)
                              : null,
                          onTap: () {
                            controller.setCustomer(customer);
                            Get.back();
                            Get.snackbar(
                              '✅ Customer Selected',
                              customer.name,
                              duration: Duration(seconds: 2),
                            );
                          },
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();

    Get.dialog(
      Dialog(
        child: Container(
          width: Get.width * 0.9,
          padding: EdgeInsets.all(20.w),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Customer',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20.h),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text('Cancel'),
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          Get.snackbar('Error', 'Customer name is required');
                          return;
                        }

                        final success = await controller.addCustomer(
                          name: nameController.text.trim(),
                          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                          email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                          address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        );

                        if (success) {
                          Get.back();
                        }
                      },
                      icon: Icon(Icons.save),
                      label: Text('Save Customer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
