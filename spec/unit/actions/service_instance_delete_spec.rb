require 'spec_helper'
require 'actions/service_instance_delete'

module VCAP::CloudController
  describe ServiceInstanceDelete do
    subject(:service_instance_delete) { ServiceInstanceDelete.new(service_instance_dataset) }

    describe '#delete' do
      let!(:service_instance_1) { ManagedServiceInstance.make }
      let!(:service_instance_2) { ManagedServiceInstance.make }

      let!(:service_binding_1) { ServiceBinding.make(service_instance: service_instance_1) }
      let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance_2) }

      let!(:service_instance_dataset) { ServiceInstance.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        [service_instance_1, service_instance_2].each do |service_instance|
          stub_deprovision(service_instance)
          stub_unbind(service_instance.service_bindings.first)
        end
      end

      it 'deletes all the service_instances' do
        expect { service_instance_delete.delete }.to change { ServiceInstance.count }.by(-2)
      end

      it 'deletes all the bindings for all the service instance' do
        expect { service_instance_delete.delete }.to change { ServiceBinding.count }.by(-2)
      end
    end
  end
end
